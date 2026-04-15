const BUILTIN_TURTLE_VARS = Set([
  "WHO", "COLOR", "HEADING", "XCOR", "YCOR", "SHAPE", "LABEL",
  "LABEL-COLOR", "BREED", "HIDDEN?", "SIZE", "PEN-SIZE", "PEN-MODE",
])
const BUILTIN_PATCH_VARS = Set(["PXCOR", "PYCOR", "PCOLOR", "PLABEL", "PLABEL-COLOR"])
const BUILTIN_LINK_VARS = Set([
  "END1", "END2", "COLOR", "LABEL", "LABEL-COLOR", "HIDDEN?",
  "BREED", "THICKNESS", "SHAPE", "TIE-MODE",
])
const BUILTIN_VARIABLE_NAMES = union(BUILTIN_TURTLE_VARS, BUILTIN_PATCH_VARS, BUILTIN_LINK_VARS)

is_identifier_start(c::Char) = isletter(c) || c == '_' || c == '#' || c == '%' || c == '$'
is_identifier_part(c::Char) = isletter(c) || isnumeric(c) || c in ('_', '-', '?', '!', ':', '\'', '%', '#', '$', '&', '/')

decode_logo_string_escape(c::Char) =
  c == '"' ? '"' :
  c == '\\' ? '\\' :
  c == 'n' ? '\n' :
  c == 't' ? '\t' :
  c == 'r' ? '\r' :
  nothing

const MODEL_SECTION_DELIMITER = raw"@#$#@#$#@"
const INCLUDE_DECLARATION_NAMES = ("INCLUDES", "__INCLUDES")

function tokenize(source::String)
  chars = collect(source)
  tokens = Token[]
  i = 1
  line = 1
  column = 1

  function span_at(start_i::Int, stop_i::Int, start_line::Int, start_column::Int)
    SourceSpan(start_i, max(start_i, stop_i), start_line, start_column)
  end

  while i <= length(chars)
    c = chars[i]
    start_i = i
    start_line = line
    start_column = column

    if c == ' ' || c == '\t' || c == '\r'
      i += 1
      column += 1
    elseif c == '\n'
      push!(tokens, Token(NewlineToken, "\n", nothing, span_at(start_i, start_i, start_line, start_column)))
      i += 1
      line += 1
      column = 1
    elseif c == ';'
      while i <= length(chars) && chars[i] != '\n'
        i += 1
        column += 1
      end
    elseif c == '['
      push!(tokens, Token(LBracketToken, "[", nothing, span_at(start_i, start_i, start_line, start_column)))
      i += 1
      column += 1
    elseif c == ']'
      push!(tokens, Token(RBracketToken, "]", nothing, span_at(start_i, start_i, start_line, start_column)))
      i += 1
      column += 1
    elseif c == '('
      push!(tokens, Token(LParenToken, "(", nothing, span_at(start_i, start_i, start_line, start_column)))
      i += 1
      column += 1
    elseif c == ')'
      push!(tokens, Token(RParenToken, ")", nothing, span_at(start_i, start_i, start_line, start_column)))
      i += 1
      column += 1
    elseif c == ','
      push!(tokens, Token(CommaToken, ",", nothing, span_at(start_i, start_i, start_line, start_column)))
      i += 1
      column += 1
    elseif c == '"'
      i += 1
      column += 1
      buffer = IOBuffer()
      while i <= length(chars)
        current = chars[i]
        if current == '\\' && i < length(chars)
          next_char = chars[i + 1]
          escaped = decode_logo_string_escape(next_char)
          if escaped !== nothing
            print(buffer, escaped)
            i += 2
            column += 2
            continue
          end
        elseif current == '"'
          break
        end
        print(buffer, current)
        i += 1
        column += 1
      end
      i <= length(chars) || throw(Diagnostic("unterminated string literal", span_at(start_i, start_i, start_line, start_column)))
      value = String(take!(buffer))
      push!(tokens, Token(StringToken, value, value, span_at(start_i, i, start_line, start_column)))
      i += 1
      column += 1
    elseif isdigit(c) || (c == '.' && i < length(chars) && isdigit(chars[i + 1]))
      while i <= length(chars) && (isdigit(chars[i]) || chars[i] == '.')
        i += 1
        column += 1
      end
      # Scientific notation: e.g. 1e-4, 2.5E+10, 3e6
      if i <= length(chars) && (chars[i] == 'e' || chars[i] == 'E')
        i += 1; column += 1
        if i <= length(chars) && (chars[i] == '+' || chars[i] == '-')
          i += 1; column += 1
        end
        while i <= length(chars) && isdigit(chars[i])
          i += 1; column += 1
        end
      end
      lexeme = join(chars[start_i:i - 1])
      push!(tokens, Token(NumberToken, lexeme, parse(Float64, lexeme), span_at(start_i, i - 1, start_line, start_column)))
    elseif c == '-' && i < length(chars) && (isdigit(chars[i + 1]) || (chars[i + 1] == '.' && i + 1 < length(chars) && isdigit(chars[i + 2])))
      # Negative number literal: -N or -.N (no space between - and digit)
      i += 1; column += 1  # skip past '-'
      while i <= length(chars) && (isdigit(chars[i]) || chars[i] == '.')
        i += 1
        column += 1
      end
      lexeme = join(chars[start_i:i - 1])
      push!(tokens, Token(NumberToken, lexeme, parse(Float64, lexeme), span_at(start_i, i - 1, start_line, start_column)))
    elseif c in ('<', '>', '!', '=', '+', '-', '*', '/', '^')
      lexeme =
        if i < length(chars) && ((c == '<' && chars[i + 1] == '=') ||
                                 (c == '>' && chars[i + 1] == '=') ||
                                 (c == '!' && chars[i + 1] == '='))
          join(chars[i:i + 1])
        else
          string(c)
        end
      push!(tokens, Token(OperatorToken, lexeme, lexeme, span_at(start_i, start_i + length(lexeme) - 1, start_line, start_column)))
      i += length(lexeme)
      column += length(lexeme)
    elseif is_identifier_start(c)
      while i <= length(chars) && is_identifier_part(chars[i])
        i += 1
        column += 1
      end
      lexeme = join(chars[start_i:i - 1])
      push!(tokens, Token(IdentifierToken, lexeme, lexeme, span_at(start_i, i - 1, start_line, start_column)))
    else
      throw(Diagnostic("unexpected character '$c'", span_at(start_i, start_i, start_line, start_column)))
    end
  end

  push!(tokens, Token(EofToken, "", nothing, SourceSpan(length(chars) + 1, length(chars) + 1, line, column)))
  tokens
end

mutable struct TokenStream
  tokens::Vector{Token}
  index::Int
end

TokenStream(tokens::Vector{Token}) = TokenStream(tokens, 1)

peek(stream::TokenStream) = stream.tokens[stream.index]
previous(stream::TokenStream) = stream.tokens[max(1, stream.index - 1)]
check(stream::TokenStream, kind::TokenKind) = peek(stream).kind == kind
peek_at(stream::TokenStream, offset::Int) = stream.tokens[min(length(stream.tokens), stream.index + offset)]

function advance!(stream::TokenStream)
  token = peek(stream)
  stream.index = min(stream.index + 1, length(stream.tokens))
  token
end

function skip_newlines!(stream::TokenStream)
  while check(stream, NewlineToken)
    advance!(stream)
  end
end

function expect!(stream::TokenStream, kind::TokenKind, message::AbstractString)
  check(stream, kind) || throw(Diagnostic(String(message), peek(stream).span))
  advance!(stream)
end

runtime_token_stream(source::String) = TokenStream(tokenize(source))

function can_start_expression(token::Token)
  token.kind in (IdentifierToken, NumberToken, StringToken, LParenToken, LBracketToken) ||
    (token.kind == OperatorToken && token.lexeme == "-")
end

struct RawProcedure
  name::String
  is_reporter::Bool
  inputs::Vector{String}
  body_tokens::Vector{Token}
  span::SourceSpan
end

function parse_identifier_list(stream::TokenStream; allow_strings::Bool=false)
  skip_newlines!(stream)
  expect!(stream, LBracketToken, "expected '['")
  names = String[]
  skip_newlines!(stream)
  while !check(stream, RBracketToken)
    token = peek(stream)
    if token.kind == IdentifierToken
      push!(names, canonical_name(token.lexeme))
    elseif allow_strings && token.kind == StringToken
      push!(names, String(token.value))
    else
      throw(Diagnostic("expected identifier", token.span))
    end
    advance!(stream)
    skip_newlines!(stream)
  end
  expect!(stream, RBracketToken, "expected ']'")
  names
end

function parse_extension_name_list(stream::TokenStream)
  skip_newlines!(stream)
  expect!(stream, LBracketToken, "expected '['")
  extensions = Pair{String, SourceSpan}[]
  skip_newlines!(stream)
  while !check(stream, RBracketToken)
    token = peek(stream)
    if token.kind == IdentifierToken
      push!(extensions, String(token.lexeme) => token.span)
    else
      throw(Diagnostic("expected identifier", token.span))
    end
    advance!(stream)
    skip_newlines!(stream)
  end
  expect!(stream, RBracketToken, "expected ']'")
  extensions
end

is_include_declaration(name::String) = name in INCLUDE_DECLARATION_NAMES

function parse_include_path_list(stream::TokenStream)
  skip_newlines!(stream)
  expect!(stream, LBracketToken, "expected '['")
  includes = Pair{String, SourceSpan}[]
  skip_newlines!(stream)
  while !check(stream, RBracketToken)
    token = peek(stream)
    if token.kind == StringToken
      push!(includes, String(token.value) => token.span)
    elseif token.kind == IdentifierToken
      push!(includes, String(token.lexeme) => token.span)
    else
      throw(Diagnostic("expected identifier", token.span))
    end
    advance!(stream)
    skip_newlines!(stream)
  end
  expect!(stream, RBracketToken, "expected ']'")
  includes
end

function parse_breed_declaration!(model::ModelSpec, stream::TokenStream; is_link_breed::Bool, directed::Bool)
  names = parse_identifier_list(stream)
  length(names) == 2 || throw(Diagnostic("breed declaration must contain plural and singular names", previous(stream).span))
  breed = BreedSpec(names[1], names[2], is_link_breed, directed, String[])
  if is_link_breed
    push!(model.link_breeds, breed)
  else
    push!(model.breeds, breed)
  end
end

function parse_breed_own_declaration!(model::ModelSpec, declaration_name::String, stream::TokenStream, token::Token)
  plural = declaration_name[1:end - 4]
  owns = parse_identifier_list(stream)
  set_turtle_breed_owns!(model, plural, owns) && return
  set_link_breed_owns!(model, plural, owns) && return
  throw(Diagnostic("unknown breed-own declaration $(token.lexeme)", token.span))
end

function parse_dynamic_link_command(name::String, token::Token, stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  for breed in model.link_breeds
    undirected_single = "CREATE-$(breed.singular)-WITH"
    undirected_multi = "CREATE-$(breed.plural)-WITH"
    directed_single_to = "CREATE-$(breed.singular)-TO"
    directed_multi_to = "CREATE-$(breed.plural)-TO"
    directed_single_from = "CREATE-$(breed.singular)-FROM"
    directed_multi_from = "CREATE-$(breed.plural)-FROM"

    if name == undirected_single || name == undirected_multi ||
       (breed.directed && (name == directed_single_to || name == directed_multi_to ||
                           name == directed_single_from || name == directed_multi_from))
      mode =
        endswith(name, "-WITH") ? "ALL" :
        endswith(name, "-TO") ? "OUT" :
        "IN"
      args = Any[
        SymbolArg(breed.plural, token.span),
        SymbolArg(mode, token.span),
        parse_expression(stream, model, registry, scope, 0),
      ]
      skip_newlines!(stream)
      if check(stream, LBracketToken)
        push!(args, parse_command_block(stream, model, registry, scope))
      end
      return CommandCall("CREATE-LINK-BREED", args, span_union(token.span, spanof(last(args)))), String[]
    end
  end

  nothing
end

function parse_dynamic_link_reporter(name::String, token::Token, model::ModelSpec)
  if startswith(name, "MY-IN-")
    breed = name[7:end]
    has_link_breed(model, breed) || return nothing
    return ReporterCall("MY-LINK-BREED", Any[SymbolArg(breed, token.span), SymbolArg("IN", token.span)], token.span)
  elseif startswith(name, "MY-OUT-")
    breed = name[8:end]
    has_link_breed(model, breed) || return nothing
    return ReporterCall("MY-LINK-BREED", Any[SymbolArg(breed, token.span), SymbolArg("OUT", token.span)], token.span)
  elseif startswith(name, "MY-")
    breed = name[4:end]
    has_link_breed(model, breed) || return nothing
    return ReporterCall("MY-LINK-BREED", Any[SymbolArg(breed, token.span), SymbolArg("ALL", token.span)], token.span)
  elseif startswith(name, "IN-") && endswith(name, "-NEIGHBORS")
    singular = name[4:end - 10]
    breed = link_breed_by_singular(model, singular)
    breed === nothing || return ReporterCall("LINK-BREED-NEIGHBORS", Any[SymbolArg(breed.plural, token.span), SymbolArg("IN", token.span)], token.span)
  elseif startswith(name, "OUT-") && endswith(name, "-NEIGHBORS")
    singular = name[5:end - 10]
    breed = link_breed_by_singular(model, singular)
    breed === nothing || return ReporterCall("LINK-BREED-NEIGHBORS", Any[SymbolArg(breed.plural, token.span), SymbolArg("OUT", token.span)], token.span)
  elseif endswith(name, "-NEIGHBORS")
    singular = name[1:end - 10]
    breed = link_breed_by_singular(model, singular)
    breed === nothing || return ReporterCall("LINK-BREED-NEIGHBORS", Any[SymbolArg(breed.plural, token.span), SymbolArg("ALL", token.span)], token.span)
  end

  nothing
end

function parse_dynamic_link_lookup_reporter(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  breed = link_breed_by_singular(model, name)
  breed === nothing && return nothing
  advance!(stream)
  end1 = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  end2 = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  ReporterCall("LINK-BREED", Any[SymbolArg(breed.plural, token.span), end1, end2], span_union(token.span, spanof(end2)))
end

function parse_dynamic_link_relation_reporter(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  breed = nothing
  mode = nothing
  if startswith(name, "IN-") && endswith(name, "-FROM")
    breed = link_breed_by_singular(model, name[4:end - 5])
    mode = "IN"
  elseif startswith(name, "OUT-") && endswith(name, "-TO")
    breed = link_breed_by_singular(model, name[5:end - 3])
    mode = "OUT"
  elseif endswith(name, "-WITH")
    breed = link_breed_by_singular(model, name[1:end - 5])
    mode = "ALL"
  end
  breed === nothing && return nothing
  advance!(stream)
  arg = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  ReporterCall("LINK-BREED-RELATION", Any[SymbolArg(breed.plural, token.span), SymbolArg(mode, token.span), arg], span_union(token.span, spanof(arg)))
end

function parse_dynamic_link_neighbor_reporter(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  breed = nothing
  mode = nothing
  if startswith(name, "IN-") && endswith(name, "-NEIGHBOR?")
    breed = link_breed_by_singular(model, name[4:end - 10])
    mode = "IN"
  elseif startswith(name, "OUT-") && endswith(name, "-NEIGHBOR?")
    breed = link_breed_by_singular(model, name[5:end - 10])
    mode = "OUT"
  elseif endswith(name, "-NEIGHBOR?")
    breed = link_breed_by_singular(model, name[1:end - 10])
    mode = "ALL"
  end
  breed === nothing && return nothing
  advance!(stream)
  arg = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  ReporterCall("LINK-BREED-NEIGHBOR?", Any[SymbolArg(breed.plural, token.span), SymbolArg(mode, token.span), arg], span_union(token.span, spanof(arg)))
end

function parse_dynamic_turtle_on_reporter(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  endswith(name, "-ON") || return nothing
  breed = name[1:end - 3]
  has_turtle_breed(model, breed) || return nothing
  advance!(stream)
  arg = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  ReporterCall("TURTLE-BREED-ON", Any[SymbolArg(breed, token.span), arg], span_union(token.span, spanof(arg)))
end

function parse_dynamic_turtle_at_reporter(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  endswith(name, "-AT") || return nothing
  breed = name[1:end - 3]
  has_turtle_breed(model, breed) || return nothing
  advance!(stream)
  dx = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  dy = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  ReporterCall("TURTLE-BREED-AT", Any[SymbolArg(breed, token.span), dx, dy], span_union(token.span, spanof(dy)))
end

function parse_dynamic_turtle_here_reporter(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  endswith(name, "-HERE") || return nothing
  breed = name[1:end - 5]
  has_turtle_breed(model, breed) || return nothing
  advance!(stream)
  ReporterCall("TURTLE-BREED-HERE", Any[SymbolArg(breed, token.span)], token.span)
end

function parse_dynamic_turtle_breed_reporter(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  breed = turtle_breed_by_singular(model, name)
  breed === nothing && return nothing
  advance!(stream)
  arg = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  ReporterCall("TURTLE-BREED", Any[SymbolArg(breed.plural, token.span), arg], span_union(token.span, spanof(arg)))
end

function parse_dynamic_breed_predicate(
  name::String,
  token::Token,
  stream::TokenStream,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String})
  startswith(name, "IS-") && endswith(name, "?") || return nothing
  singular = name[4:(end - 1)]
  turtle_breed = turtle_breed_by_singular(model, singular)
  primitive =
    turtle_breed === nothing ? nothing : ("IS-TURTLE-BREED?", turtle_breed.plural)
  if primitive === nothing
    link_breed = link_breed_by_singular(model, singular)
    primitive =
      link_breed === nothing ? nothing : ("IS-LINK-BREED?", link_breed.plural)
  end
  primitive === nothing && return nothing
  advance!(stream)
  arg = parse_expression(stream, model, registry, scope, PrefixPrecedence)
  ReporterCall(first(primitive), Any[SymbolArg(last(primitive), token.span), arg], span_union(token.span, spanof(arg)))
end

function parse_raw_procedure!(stream::TokenStream, start_token::Token)
  name_token = expect!(stream, IdentifierToken, "expected procedure name")
  inputs = check(stream, LBracketToken) ? parse_identifier_list(stream) : String[]
  skip_newlines!(stream)

  body_tokens = Token[]
  bracket_depth = 0
  paren_depth = 0
  while !check(stream, EofToken)
    token = advance!(stream)
    if token.kind == LBracketToken
      bracket_depth += 1
    elseif token.kind == RBracketToken
      bracket_depth -= 1
    elseif token.kind == LParenToken
      paren_depth += 1
    elseif token.kind == RParenToken
      paren_depth -= 1
    elseif token.kind == IdentifierToken && bracket_depth == 0 && paren_depth == 0 && canonical_name(token.lexeme) == "END"
      return RawProcedure(
        canonical_name(name_token.lexeme),
        canonical_name(start_token.lexeme) == "TO-REPORT",
        inputs,
        body_tokens,
        span_union(start_token.span, token.span))
    end
    push!(body_tokens, token)
  end

  throw(Diagnostic("unterminated procedure $(name_token.lexeme)", name_token.span))
end

function split_model_sections(source::String)
  sections = split(source, MODEL_SECTION_DELIMITER; limit=3)
  code_source = String(sections[1])
  interface_source = length(sections) >= 2 ? String(sections[2]) : ""
  code_source, interface_source, length(sections) >= 2
end

function extract_turtle_shapes_section(source::String)
  sections = split(source, MODEL_SECTION_DELIMITER)
  length(sections) >= 4 ? strip(String(sections[4])) : ""
end

function parse_interface_number(::Type{T}, value::AbstractString, description::AbstractString) where {T<:Number}
  try
    parse(T, strip(String(value)))
  catch
    throw(Diagnostic("invalid $description", SourceSpan()))
  end
end

function parse_interface_bool(value::AbstractString, description::AbstractString)
  normalized = strip(String(value))
  normalized == "true" && return true
  normalized == "false" && return false
  throw(Diagnostic("invalid $description", SourceSpan()))
end

function parse_interface_binary_bool(value::AbstractString, description::AbstractString)
  normalized = strip(String(value))
  normalized == "1" && return true
  normalized == "0" && return false
  throw(Diagnostic("invalid $description", SourceSpan()))
end

function parse_interface_inverted_binary_bool(value::AbstractString, description::AbstractString)
  normalized = strip(String(value))
  normalized == "0" && return true
  normalized == "1" && return false
  throw(Diagnostic("invalid $description", SourceSpan()))
end

function parse_interface_tnil_bool(value::AbstractString, description::AbstractString)
  normalized = strip(String(value))
  normalized == "T" && return true
  normalized == "NIL" && return false
  throw(Diagnostic("invalid $description", SourceSpan()))
end

function parse_optional_interface_string(value::AbstractString)
  normalized = strip(String(value))
  normalized == "NIL" ? "" : normalized
end

function unescape_logo_string(value::AbstractString)
  chars = collect(String(value))
  buffer = IOBuffer()
  index = 1
  while index <= length(chars)
    current = chars[index]
    if current == '\\' && index < length(chars)
      escaped = decode_logo_string_escape(chars[index + 1])
      if escaped !== nothing
        print(buffer, escaped)
        index += 2
        continue
      end
    end
    print(buffer, current)
    index += 1
  end
  String(take!(buffer))
end

function parse_optional_escaped_interface_string(value::AbstractString)
  normalized = strip(String(value))
  normalized == "NIL" ? "" : unescape_logo_string(normalized)
end

function parse_optional_interface_char(value::AbstractString, description::AbstractString)
  normalized = strip(String(value))
  normalized == "NIL" && return nothing
  length(normalized) == 1 && return only(normalized)
  throw(Diagnostic("invalid $description", SourceSpan()))
end

function parse_widget_bounds(lines::Vector{String}, description::AbstractString)
  length(lines) >= 5 || throw(Diagnostic("invalid $description definition", SourceSpan()))
  (
    parse_interface_number(Int, lines[2], "$description left"),
    parse_interface_number(Int, lines[3], "$description top"),
    parse_interface_number(Int, lines[4], "$description right"),
    parse_interface_number(Int, lines[5], "$description bottom"),
  )
end

function parse_button_kind(value::AbstractString)
  normalized = uppercase(strip(String(value)))
  normalized in ("OBSERVER", "PATCH", "TURTLE", "LINK") && return normalized
  throw(Diagnostic("invalid button kind", SourceSpan()))
end

function skip_widget_whitespace(chars::Vector{Char}, index::Int)
  while index <= length(chars) && isspace(chars[index])
    index += 1
  end
  index
end

function parse_widget_string_literal(chars::Vector{Char}, index::Int)
  index = skip_widget_whitespace(chars, index)
  index <= length(chars) && chars[index] == '"' || throw(Diagnostic("expected string literal", SourceSpan()))
  index += 1
  buffer = IOBuffer()
  while index <= length(chars)
    current = chars[index]
    if current == '\\' && index < length(chars)
      escaped = decode_logo_string_escape(chars[index + 1])
      if escaped !== nothing
        print(buffer, escaped)
        index += 2
        continue
      end
    elseif current == '"'
      return String(take!(buffer)), index + 1
    end
    print(buffer, current)
    index += 1
  end
  throw(Diagnostic("unterminated string literal", SourceSpan()))
end

function parse_widget_string_literals(line::AbstractString)
  chars = collect(String(line))
  index = skip_widget_whitespace(chars, 1)
  literals = String[]
  while index <= length(chars) && chars[index] == '"'
    literal, index = parse_widget_string_literal(chars, index)
    push!(literals, literal)
    index = skip_widget_whitespace(chars, index)
  end
  literals
end

string_from_chars(chars::Vector{Char}, start::Int, stop::Int) = start > stop ? "" : String(chars[start:stop])

widget_global_name(::InterfaceWidgetSpec) = nothing
widget_global_value(::InterfaceWidgetSpec) = nothing
widget_global_name(widget::SliderWidgetSpec) = widget.variable
widget_global_value(widget::SliderWidgetSpec) = widget.default_value
widget_global_name(widget::SwitchWidgetSpec) = widget.variable
widget_global_value(widget::SwitchWidgetSpec) = widget.on
widget_global_name(widget::ChooserWidgetSpec) = widget.variable
widget_global_value(widget::ChooserWidgetSpec) = isempty(widget.choices) ? "" : widget.choices[widget.current_choice + 1]
widget_global_name(widget::InputBoxWidgetSpec) = widget.variable
widget_global_value(widget::InputBoxWidgetSpec) = widget.value

function register_interface_global!(model::ModelSpec, widget::InterfaceWidgetSpec)
  name = widget_global_name(widget)
  name === nothing && return nothing
  canonical = canonical_name(name)
  isempty(canonical) && return nothing
  canonical in model.globals || push!(model.globals, canonical)
  model.interface_globals[canonical] = widget_global_value(widget)
  nothing
end

function parse_plot_code_pair(line::AbstractString)
  stripped = strip(String(line))
  isempty(stripped) && return "", ""
  literals = parse_widget_string_literals(stripped)
  length(literals) == 2 || throw(Diagnostic("expected plot setup and update code", SourceSpan()))
  literals[1], literals[2]
end

function parse_plot_pen_spec(line::AbstractString)
  chars = collect(String(line))
  index = skip_widget_whitespace(chars, 1)
  name, index = parse_widget_string_literal(chars, index)
  index = skip_widget_whitespace(chars, index)
  metadata_start = index
  while index <= length(chars) && chars[index] != '"'
    index += 1
  end
  metadata = split(strip(string_from_chars(chars, metadata_start, index - 1)))
  length(metadata) == 4 || throw(Diagnostic("invalid plot pen definition", SourceSpan()))
  interval = parse_interface_number(Float64, metadata[1], "plot pen interval")
  mode = parse_interface_number(Int, metadata[2], "plot pen mode")
  mode in 0:2 || throw(Diagnostic("invalid plot pen mode", SourceSpan()))
  color = parse_interface_number(Int, metadata[3], "plot pen color")
  in_legend = parse_interface_bool(metadata[4], "plot pen legend flag")
  remainder = index <= length(chars) ? string_from_chars(chars, index, length(chars)) : ""
  setup_code, update_code = parse_plot_code_pair(remainder)
  PlotPenSpec(name, color, interval, mode, in_legend, setup_code, update_code)
end

function parse_view_widget(lines::Vector{String})
  length(lines) >= 21 || throw(Diagnostic("invalid graphics window definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "graphics window")
  ViewWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_interface_number(Float64, lines[8], "graphics window patch size"),
    parse_interface_number(Int, lines[10], "graphics window font size"),
    parse_interface_binary_bool(lines[15], "graphics window wrap-x flag"),
    parse_interface_binary_bool(lines[16], "graphics window wrap-y flag"),
    parse_interface_number(Int, lines[18], "graphics window minimum x"),
    parse_interface_number(Int, lines[19], "graphics window maximum x"),
    parse_interface_number(Int, lines[20], "graphics window minimum y"),
    parse_interface_number(Int, lines[21], "graphics window maximum y"),
    length(lines) >= 24 ? parse_interface_binary_bool(lines[24], "graphics window tick counter flag") : false,
    length(lines) >= 25 ? parse_optional_interface_string(lines[25]) : "",
    length(lines) >= 26 ? parse_interface_number(Float64, lines[26], "graphics window frame rate") : 30.0)
end

function parse_slider_widget(lines::Vector{String})
  length(lines) >= 14 || throw(Diagnostic("invalid slider definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "slider")
  SliderWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_optional_interface_string(lines[6]),
    parse_optional_interface_string(lines[7]),
    strip(String(lines[8])),
    strip(String(lines[9])),
    parse_interface_number(Float64, lines[10], "slider value"),
    strip(String(lines[11])),
    parse_optional_interface_string(lines[13]),
    parse_optional_interface_string(lines[14]))
end

function parse_switch_widget(lines::Vector{String})
  length(lines) >= 10 || throw(Diagnostic("invalid switch definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "switch")
  SwitchWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_optional_interface_string(lines[6]),
    parse_optional_interface_string(lines[7]),
    parse_interface_inverted_binary_bool(lines[8], "switch value"))
end

function parse_chooser_widget(lines::Vector{String})
  length(lines) >= 9 || throw(Diagnostic("invalid chooser definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "chooser")
  choices_source = strip(String(lines[8]))
  choices_value =
    isempty(choices_source) ? Any[] : try
      read_literal_from_string("[" * choices_source * "]")
    catch err
      if err isa LiteralParseError
        throw(Diagnostic("invalid chooser choices", SourceSpan()))
      end
      rethrow()
    end
  choices_value isa Vector || throw(Diagnostic("invalid chooser choices", SourceSpan()))
  choices = Any[choices_value...]
  current_choice = parse_interface_number(Int, lines[9], "chooser current choice")
  isempty(choices) || (0 <= current_choice < length(choices)) || throw(Diagnostic("invalid chooser current choice", SourceSpan()))
  ChooserWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_optional_escaped_interface_string(lines[6]),
    parse_optional_interface_string(lines[7]),
    choices,
    current_choice)
end

function parse_input_box_widget(lines::Vector{String})
  length(lines) >= 10 || throw(Diagnostic("invalid input box definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "input box")
  value_kind = strip(String(lines[10]))
  raw_value = parse_optional_escaped_interface_string(lines[7])
  value =
    if value_kind == "Number" || value_kind == "Color"
      isempty(raw_value) ? 0.0 : parse_interface_number(Float64, raw_value, "input box value")
    else
      raw_value
    end
  InputBoxWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_optional_interface_string(lines[6]),
    value,
    parse_interface_binary_bool(lines[9], "input box multiline flag"),
    value_kind)
end

function parse_monitor_widget(lines::Vector{String})
  length(lines) >= 10 || throw(Diagnostic("invalid monitor definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "monitor")
  MonitorWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_optional_interface_string(lines[6]),
    parse_optional_escaped_interface_string(lines[7]),
    parse_interface_number(Int, lines[8], "monitor precision"),
    parse_interface_number(Int, lines[10], "monitor font size"))
end

function parse_button_widget(lines::Vector{String})
  length(lines) >= 11 || throw(Diagnostic("invalid button definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "button")
  action_key =
    if length(lines) >= 16
      parse_optional_interface_char(lines[13], "button action key")
    elseif length(lines) >= 12
      parse_optional_interface_char(lines[12], "button action key")
    else
      nothing
    end
  disable_until_ticks_start =
    length(lines) >= 16 ? parse_interface_number(Int, lines[16], "button enabled-before-ticks flag") == 0 : false
  ButtonWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_optional_interface_string(lines[6]),
    parse_optional_escaped_interface_string(lines[7]),
    parse_interface_tnil_bool(lines[8], "button forever flag"),
    parse_button_kind(lines[11]),
    action_key,
    disable_until_ticks_start)
end

function parse_text_box_widget(lines::Vector{String})
  length(lines) >= 6 || throw(Diagnostic("invalid text box definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "text box")
  TextBoxWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_optional_escaped_interface_string(lines[6]),
    length(lines) >= 7 ? parse_interface_number(Int, lines[7], "text box font size") : 12,
    length(lines) >= 8 ? parse_interface_number(Float64, lines[8], "text box color") : 0.0,
    length(lines) >= 9 ? parse_interface_binary_bool(lines[9], "text box transparency flag") : false)
end

function parse_output_widget(lines::Vector{String})
  length(lines) >= 6 || throw(Diagnostic("invalid output definition", SourceSpan()))
  left, top, right, bottom = parse_widget_bounds(lines, "output")
  OutputWidgetSpec(
    left,
    top,
    right,
    bottom,
    parse_interface_number(Int, lines[6], "output font size"))
end

function parse_plot_widget(lines::Vector{String})
  pens_index = findfirst(line -> strip(line) == "PENS", lines)
  plot_lines = pens_index === nothing ? lines : lines[1:pens_index - 1]
  pen_lines = pens_index === nothing ? String[] : lines[pens_index + 1:end]
  length(plot_lines) >= 14 || throw(Diagnostic("invalid plot definition", SourceSpan()))

  parse_interface_number(Int, plot_lines[2], "plot left")
  parse_interface_number(Int, plot_lines[3], "plot top")
  parse_interface_number(Int, plot_lines[4], "plot right")
  parse_interface_number(Int, plot_lines[5], "plot bottom")

  auto_plot_on = parse_interface_bool(plot_lines[13], "plot auto-plot flag")
  legend_open = parse_interface_bool(plot_lines[14], "plot legend flag")
  code_line = length(plot_lines) >= 15 ? plot_lines[15] : "\"\" \"\""
  setup_code, update_code = parse_plot_code_pair(code_line)

  PlotSpec(
    parse_optional_interface_string(plot_lines[6]),
    parse_optional_interface_string(plot_lines[7]),
    parse_optional_interface_string(plot_lines[8]),
    parse_interface_number(Float64, plot_lines[9], "plot x minimum"),
    parse_interface_number(Float64, plot_lines[10], "plot x maximum"),
    parse_interface_number(Float64, plot_lines[11], "plot y minimum"),
    parse_interface_number(Float64, plot_lines[12], "plot y maximum"),
    auto_plot_on,
    auto_plot_on,
    legend_open,
    setup_code,
    update_code,
    [parse_plot_pen_spec(line) for line in pen_lines])
end

function split_interface_widgets(interface_source::String)
  normalized = replace(interface_source, "\r\n" => "\n", "\r" => "\n")
  widgets = Vector{Vector{String}}()
  current = String[]
  for line in split(normalized, '\n'; keepempty=true)
    if isempty(line)
      isempty(current) || (push!(widgets, current); current = String[])
    else
      push!(current, line)
    end
  end
  isempty(current) || push!(widgets, current)
  widgets
end

function parse_interface_widgets!(model::ModelSpec, interface_source::String)
  empty!(model.plots)
  empty!(model.interface_widgets)
  empty!(model.interface_globals)
  model.view_widget = nothing
  for widget_lines in split_interface_widgets(interface_source)
    isempty(widget_lines) && continue
    kind = strip(widget_lines[1])
    if kind == "PLOT"
      push!(model.plots, parse_plot_widget(widget_lines))
    elseif kind == "GRAPHICS-WINDOW"
      view = parse_view_widget(widget_lines)
      push!(model.interface_widgets, view)
      model.view_widget = view
    elseif kind == "SLIDER"
      widget = parse_slider_widget(widget_lines)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif kind == "SWITCH"
      widget = parse_switch_widget(widget_lines)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif kind == "CHOOSER"
      widget = parse_chooser_widget(widget_lines)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif kind == "INPUTBOX"
      widget = parse_input_box_widget(widget_lines)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif kind == "MONITOR"
      push!(model.interface_widgets, parse_monitor_widget(widget_lines))
    elseif kind == "BUTTON"
      push!(model.interface_widgets, parse_button_widget(widget_lines))
    elseif kind == "TEXTBOX"
      push!(model.interface_widgets, parse_text_box_widget(widget_lines))
    elseif kind == "OUTPUT"
      push!(model.interface_widgets, parse_output_widget(widget_lines))
    end
  end
  nothing
end

function validate_plot_callback_code!(model::ModelSpec, registry::PrimitiveRegistry, code::AbstractString, description::AbstractString)
  isempty(strip(String(code))) && return
  try
    parse_runtime_commands(String(code), model, registry, Set{String}())
  catch err
    if err isa Diagnostic
      throw(Diagnostic("invalid $description: $(err.message)", err.span))
    end
    rethrow()
  end
end

validate_interface_widget!(model::ModelSpec, registry::PrimitiveRegistry, widget::InterfaceWidgetSpec) = nothing

ignorable_interface_widget_diagnostic(err::Diagnostic) =
  startswith(err.message, "unknown command ") || startswith(err.message, "unknown reporter ")

function validate_interface_widget!(model::ModelSpec, registry::PrimitiveRegistry, widget::ButtonWidgetSpec)
  isempty(strip(widget.source)) && return nothing
  try
    parse_runtime_commands(widget.source, model, registry, Set{String}())
  catch err
    if err isa Diagnostic
      ignorable_interface_widget_diagnostic(err) && return nothing
      throw(Diagnostic("invalid button code: $(err.message)", err.span))
    end
    rethrow()
  end
  nothing
end

function validate_interface_widget!(model::ModelSpec, registry::PrimitiveRegistry, widget::MonitorWidgetSpec)
  isempty(strip(widget.source)) && return nothing
  try
    parse_runtime_reporter(widget.source, model, registry, Set{String}())
  catch err
    if err isa Diagnostic
      ignorable_interface_widget_diagnostic(err) && return nothing
      throw(Diagnostic("invalid monitor source: $(err.message)", err.span))
    end
    rethrow()
  end
  nothing
end

function validate_plot_specs!(model::ModelSpec, registry::PrimitiveRegistry)
  for plot in model.plots
    validate_plot_callback_code!(model, registry, plot.setup_code, "plot setup code")
    validate_plot_callback_code!(model, registry, plot.update_code, "plot update code")
    for pen in plot.pens
      validate_plot_callback_code!(model, registry, pen.setup_code, "plot pen setup code")
      validate_plot_callback_code!(model, registry, pen.update_code, "plot pen update code")
    end
  end
  nothing
end

function validate_interface_widgets!(model::ModelSpec, registry::PrimitiveRegistry)
  foreach(widget -> validate_interface_widget!(model, registry, widget), model.interface_widgets)
  nothing
end

function collect_model_include_specs(code_source::String)
  stream = TokenStream(tokenize(code_source))
  includes = Pair{String, SourceSpan}[]

  while !check(stream, EofToken)
    skip_newlines!(stream)
    check(stream, EofToken) && break
    token = expect!(stream, IdentifierToken, "expected a declaration or procedure")
    name = canonical_name(token.lexeme)

    if name in ("GLOBALS", "TURTLES-OWN", "PATCHES-OWN", "LINKS-OWN", "EXTENSIONS")
      parse_identifier_list(stream)
    elseif name == "BREED" || name == "DIRECTED-LINK-BREED" || name == "UNDIRECTED-LINK-BREED" || endswith(name, "-OWN")
      parse_identifier_list(stream)
    elseif is_include_declaration(name)
      append!(includes, parse_include_path_list(stream))
    elseif name == "TO" || name == "TO-REPORT"
      parse_raw_procedure!(stream, token)
    else
      throw(Diagnostic("unknown top-level form $(token.lexeme)", token.span))
    end
    skip_newlines!(stream)
  end

  includes
end

function expand_model_included_code(code_source::String, source_path::AbstractString, include_stack::Vector{String}=String[]; include_specs::Union{Nothing, Vector{Pair{String, SourceSpan}}}=nothing)
  specs = include_specs === nothing ? collect_model_include_specs(code_source) : include_specs
  isempty(specs) && return code_source

  source_file = normpath(abspath(String(source_path)))
  source_dir = dirname(source_file)
  stack = isempty(include_stack) ? String[source_file] : include_stack
  included_sources = String[]

  for (include_name, include_span) in specs
    endswith(lowercase(include_name), ".nls") || throw(Diagnostic("Included files must end with .nls", include_span))
    resolved_path =
      isabspath(include_name) ?
      normpath(include_name) :
      normpath(joinpath(source_dir, include_name))
    isfile(resolved_path) || throw(Diagnostic("Could not find $(include_name)", include_span))
    resolved_path in stack && throw(Diagnostic("Circular __includes detected for $(include_name)", include_span))

    included_source = read(resolved_path, String)
    included_code, _, _ = split_model_sections(included_source)
    push!(
      included_sources,
      expand_model_included_code(
        included_code,
        resolved_path,
        vcat(stack, resolved_path)))
  end

  code_source * "\n" * join(included_sources, "\n")
end

function parse_model(
  source::String,
  registry::PrimitiveRegistry;
  source_path::Union{Nothing, AbstractString}=nothing,
  extension_host::Module=Main)
  if is_nlogox_source(source)
    return parse_nlogox_model(source, registry; source_path=source_path, extension_host=extension_host)
  end
  code_source, interface_source, has_interface_section = split_model_sections(source)

  # Generate SD code from section 6 and prepend to code section
  sd_section = extract_sd_section(source)
  sd_code = parse_sd_section(sd_section)
  if !isempty(sd_code)
    code_source = sd_code * "\n" * code_source
  end

  include_specs = collect_model_include_specs(code_source)
  if source_path === nothing
    isempty(include_specs) || throw(Diagnostic("Can't resolve __includes without a source path", last(first(include_specs))))
    model_source = source
  else
    if isempty(include_specs)
      model_source = source
    else
      code_source = expand_model_included_code(code_source, source_path; include_specs=include_specs)
      model_source =
        has_interface_section ?
        code_source * "\n" * MODEL_SECTION_DELIMITER * "\n" * interface_source :
        code_source
    end
  end
  stream = TokenStream(tokenize(code_source))
  model = ModelSpec(model_source)
  model.has_interface_section = has_interface_section
  model.turtle_shapes_text = extract_turtle_shapes_section(source)
  model.source_path = source_path === nothing ? nothing : String(source_path)
  raw_procedures = RawProcedure[]
  extension_specs = Pair{String, SourceSpan}[]

  while !check(stream, EofToken)
    skip_newlines!(stream)
    check(stream, EofToken) && break
    token = expect!(stream, IdentifierToken, "expected a declaration or procedure")
    name = canonical_name(token.lexeme)

    if name == "GLOBALS"
      append!(model.globals, parse_identifier_list(stream))
    elseif name == "TURTLES-OWN"
      append!(model.turtles_own, parse_identifier_list(stream))
    elseif name == "PATCHES-OWN"
      append!(model.patches_own, parse_identifier_list(stream))
    elseif name == "LINKS-OWN"
      append!(model.links_own, parse_identifier_list(stream))
    elseif name == "BREED"
      parse_breed_declaration!(model, stream; is_link_breed=false, directed=false)
    elseif name == "DIRECTED-LINK-BREED"
      parse_breed_declaration!(model, stream; is_link_breed=true, directed=true)
    elseif name == "UNDIRECTED-LINK-BREED"
      parse_breed_declaration!(model, stream; is_link_breed=true, directed=false)
    elseif endswith(name, "-OWN")
      parse_breed_own_declaration!(model, name, stream, token)
    elseif name == "EXTENSIONS"
      specs = parse_extension_name_list(stream)
      append!(model.extensions, first.(specs))
      append!(extension_specs, specs)
    elseif is_include_declaration(name)
      append!(model.includes, first.(parse_include_path_list(stream)))
    elseif name == "TO" || name == "TO-REPORT"
      push!(raw_procedures, parse_raw_procedure!(stream, token))
    else
      throw(Diagnostic("unknown top-level form $(token.lexeme)", token.span))
    end
    skip_newlines!(stream)
  end

  load_extensions!(registry, extension_specs; host_module=extension_host)

  for raw in raw_procedures
    model.procedures[raw.name] = ProcedureSpec(raw.name, raw.is_reporter, raw.inputs, BlockNode(AbstractStmt[], raw.span), raw.span)
    push!(model.procedure_order, raw.name)
  end

  parse_interface_widgets!(model, interface_source)

  for raw in raw_procedures
    body = parse_procedure_body(raw, model, registry)
    model.procedures[raw.name] = ProcedureSpec(raw.name, raw.is_reporter, raw.inputs, body, raw.span)
  end

  validate_plot_specs!(model, registry)
  validate_interface_widgets!(model, registry)
  model
end

function parse_procedure_body(raw::RawProcedure, model::ModelSpec, registry::PrimitiveRegistry)
  eof_token = Token(EofToken, "", nothing, raw.span)
  stream = TokenStream(vcat(raw.body_tokens, [eof_token]))
  scope = Set{String}(raw.inputs)
  parse_block(stream, model, registry, scope; terminator=EofToken)
end

function parse_runtime_commands(source::String, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  stream = runtime_token_stream(source)
  parse_block(stream, model, registry, scope; terminator=EofToken)
end

function parse_runtime_reporter(source::String, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  # Replace newlines with spaces so multi-line monitor/reporter expressions parse as one expression
  flattened_source = replace(source, r"\r?\n" => " ")
  stream = runtime_token_stream(flattened_source)
  skip_newlines!(stream)
  check(stream, EofToken) && throw(Diagnostic("Expected reporter.", peek(stream).span))
  expr = parse_expression(stream, model, registry, scope, 0)
  skip_newlines!(stream)
  check(stream, EofToken) || throw(Diagnostic("Expected reporter.", peek(stream).span))
  expr
end

function parse_block(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, inherited_scope::Set{String}; terminator::TokenKind)
  scope = Set{String}(inherited_scope)
  statements = AbstractStmt[]
  skip_newlines!(stream)
  start_span = peek(stream).span

  while !check(stream, terminator) && !check(stream, EofToken)
    statement, bindings = parse_statement(stream, model, registry, scope)
    push!(statements, statement)
    union!(scope, bindings)
    skip_newlines!(stream)
  end

  end_span =
    if terminator == EofToken
      isempty(statements) ? start_span : spanof(statements[end])
    else
      expect!(stream, terminator, "expected block terminator").span
    end

  BlockNode(statements, span_union(start_span, end_span))
end

function parse_parenthesized_command(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  lparen = peek(stream)
  advance!(stream)  # skip (
  skip_newlines!(stream)

  # Parse the inner statement (command + its normal arguments)
  inner_token = peek(stream)
  inner_token.kind == IdentifierToken || throw(Diagnostic("expected command", inner_token.span))
  name = canonical_name(inner_token.lexeme)
  # Normalize legacy aliases
  if name == "IF-ELSE"; name = "IFELSE"; end
  if name == "IF-ELSE-VALUE"; name = "IFELSE-VALUE"; end
  advance!(stream)

  # Parse the command's normal arguments
  local args::Vector{Any}
  local bindings::Vector{String}

  if name == "FOREACH"
    stmt, bindings = parse_foreach_statement(stream, inner_token, model, registry, scope)
    # Collect extra variadic args
    skip_newlines!(stream)
    while !check(stream, RParenToken) && !check(stream, EofToken)
      skip_newlines!(stream)
      check(stream, RParenToken) && break
      push!(stmt.args, parse_expression(stream, model, registry, scope, 0))
      skip_newlines!(stream)
    end
    expect!(stream, RParenToken, "expected ')'")
    return stmt, bindings
  end

  if name == "IFELSE"
    # Variadic ifelse: (ifelse cond1 [block1] cond2 [block2] ... [else-block])
    args = Any[]
    bindings = String[]
    skip_newlines!(stream)
    while !check(stream, RParenToken) && !check(stream, EofToken)
      skip_newlines!(stream)
      check(stream, RParenToken) && break
      if check(stream, LBracketToken)
        # Could be an else block (a command block not preceded by a condition)
        # OR a condition expression starting with a reporter block like [ breed ] of x
        # Try as condition expression first when we expect one (even number of args)
        if iseven(length(args))
          saved_index = stream.index
          try
            cond = parse_expression(stream, model, registry, scope, 0)
            skip_newlines!(stream)
            if check(stream, LBracketToken)
              push!(args, cond)
              push!(args, parse_command_block(stream, model, registry, scope))
              skip_newlines!(stream)
              continue
            end
          catch err
            err isa Diagnostic || rethrow()
          end
          stream.index = saved_index
        end
        # Fall back to else block
        push!(args, parse_command_block(stream, model, registry, scope))
        skip_newlines!(stream)
        break
      end
      # Parse condition expression
      push!(args, parse_expression(stream, model, registry, scope, 0))
      skip_newlines!(stream)
      # Parse the corresponding command block
      push!(args, parse_command_block(stream, model, registry, scope))
      skip_newlines!(stream)
    end
    expect!(stream, RParenToken, "expected ')'")
    return CommandCall(name, args, span_union(lparen.span, previous(stream).span)), bindings
  end

  spec = get_command(registry, name)
  if spec !== nothing
    args = parse_call_arguments(
      stream, spec.syntax, model, registry, scope;
      expression_min_precedence=0,
      repeatable_across_newlines=name != "RUN")
    bindings = name == "LET" && !isempty(args) && args[1] isa SymbolArg ? [args[1].name] : String[]
  else
    procedure = get(model.procedures, name, nothing)
    if procedure !== nothing && !procedure.is_reporter
      args = Any[parse_expression(stream, model, registry, scope, 0) for _ in procedure.inputs]
      bindings = String[]
    else
      throw(Diagnostic("unknown command $(inner_token.lexeme)", inner_token.span))
    end
  end

  # Collect extra variadic arguments until )
  skip_newlines!(stream)
  while !check(stream, RParenToken) && !check(stream, EofToken)
    skip_newlines!(stream)
    check(stream, RParenToken) && break
    push!(args, parse_expression(stream, model, registry, scope, 0))
    skip_newlines!(stream)
  end

  expect!(stream, RParenToken, "expected ')'")
  return CommandCall(name, args, span_union(lparen.span, previous(stream).span)), bindings
end

function parse_statement(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  skip_newlines!(stream)
  token = peek(stream)

  # Handle parenthesized command calls: (command arg1 arg2 ...)
  if token.kind == LParenToken
    return parse_parenthesized_command(stream, model, registry, scope)
  end

  token.kind == IdentifierToken || throw(Diagnostic("expected command", token.span))
  name = canonical_name(token.lexeme)
  # Normalize legacy aliases
  if name == "IF-ELSE"; name = "IFELSE"; end
  advance!(stream)

  if name == "FOREACH"
    return parse_foreach_statement(stream, token, model, registry, scope)
  end

  spec = get_command(registry, name)
  if spec !== nothing
    # Destructuring let: let [var1 var2 ...] expr
    if name == "LET" && check(stream, LBracketToken)
      return parse_destructuring_let(stream, token, model, registry, scope)
    end
    args = parse_call_arguments(
      stream, spec.syntax, model, registry, scope;
      expression_min_precedence=0,
      repeatable_across_newlines=false)
    bindings = name == "LET" && !isempty(args) && args[1] isa SymbolArg ? [args[1].name] : String[]
    return CommandCall(name, args, span_union(token.span, isempty(args) ? token.span : spanof(last(args)))), bindings
  end

  procedure = get(model.procedures, name, nothing)
  if procedure !== nothing && !procedure.is_reporter
    args = Any[]
    for (i, _) in enumerate(procedure.inputs)
      i > 1 && skip_newlines!(stream)
      push!(args, parse_expression(stream, model, registry, scope, 0))
    end
    return CommandCall(name, args, span_union(token.span, isempty(args) ? token.span : spanof(last(args)))), String[]
  end

  if startswith(name, "CREATE-ORDERED-") && has_turtle_breed(model, name[16:end])
    breed_name = name[16:end]
    args = Any[SymbolArg(breed_name, token.span), parse_expression(stream, model, registry, scope, 0)]
    skip_newlines!(stream)
    if check(stream, LBracketToken)
      push!(args, parse_command_block(stream, model, registry, scope))
    end
    return CommandCall("CREATE-ORDERED-BREED", args, span_union(token.span, spanof(last(args)))), String[]
  end

  if startswith(name, "CREATE-") && has_turtle_breed(model, name[8:end])
    breed_name = name[8:end]
    args = Any[SymbolArg(breed_name, token.span), parse_expression(stream, model, registry, scope, 0)]
    skip_newlines!(stream)
    if check(stream, LBracketToken)
      push!(args, parse_command_block(stream, model, registry, scope))
    end
    return CommandCall("CREATE-BREED", args, span_union(token.span, spanof(last(args)))), String[]
  end

  if startswith(name, "HATCH-") && has_turtle_breed(model, name[7:end])
    breed_name = name[7:end]
    args = Any[SymbolArg(breed_name, token.span), parse_expression(stream, model, registry, scope, 0)]
    skip_newlines!(stream)
    if check(stream, LBracketToken)
      push!(args, parse_command_block(stream, model, registry, scope))
    end
    return CommandCall("HATCH-BREED", args, span_union(token.span, spanof(last(args)))), String[]
  end

  if startswith(name, "SPROUT-") && has_turtle_breed(model, name[8:end])
    breed_name = name[8:end]
    args = Any[SymbolArg(breed_name, token.span), parse_expression(stream, model, registry, scope, 0)]
    skip_newlines!(stream)
    if check(stream, LBracketToken)
      push!(args, parse_command_block(stream, model, registry, scope))
    end
    return CommandCall("SPROUT-BREED", args, span_union(token.span, spanof(last(args)))), String[]
  end

  dynamic_link_command = parse_dynamic_link_command(name, token, stream, model, registry, scope)
  dynamic_link_command !== nothing && return dynamic_link_command

  throw(Diagnostic("unknown command $(token.lexeme)", token.span))
end

# Parse `let [var1 var2 ...] expr` — destructuring let (NetLogo 7 syntax).
# Emits a synthetic LET-DESTRUCTURE command with SymbolArg names + the value expression.
function parse_destructuring_let(stream::TokenStream, let_token::Token, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  expect!(stream, LBracketToken, "expected '[' for destructuring let")
  names = String[]
  while !check(stream, RBracketToken)
    skip_newlines!(stream)
    check(stream, RBracketToken) && break
    t = expect!(stream, IdentifierToken, "expected variable name in destructuring let")
    push!(names, canonical_name(t.lexeme))
  end
  expect!(stream, RBracketToken, "expected ']' to end destructuring let names")
  skip_newlines!(stream)
  value = parse_expression(stream, model, registry, scope, 0)
  args = Any[SymbolArg.(names, Ref(let_token.span))..., value]
  bindings = names
  return CommandCall("LET-DESTRUCTURE", args, span_union(let_token.span, spanof(value))), bindings
end

function parse_foreach_statement(stream::TokenStream, token::Token, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  args = Any[]

  while true
    skip_newlines!(stream)
    peek(stream).kind in (EofToken, NewlineToken, RBracketToken, RParenToken) &&
      throw(Diagnostic("FOREACH expects at least one list and an anonymous command", peek(stream).span))

    saved_index = stream.index
    try
      task = parse_command_task(stream, model, registry, scope)
      if !isempty(args) && peek(stream).kind in (EofToken, NewlineToken, RBracketToken, RParenToken)
        push!(args, task)
        return CommandCall("FOREACH", args, span_union(token.span, spanof(last(args)))), String[]
      end
    catch err
      err isa Diagnostic || rethrow()
    end

    stream.index = saved_index
    push!(args, parse_expression(stream, model, registry, scope, 0))
  end
end

function parse_call_arguments(
  stream::TokenStream,
  syntax::PrimitiveSyntax,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String};
  expression_min_precedence::Int,
  repeatable_across_newlines::Bool=true)
  args = Any[]
  for (index, mask) in enumerate(syntax.right)
    stop_repeatable_at_newline = !repeatable_across_newlines && is_repeatable(mask)
    # Skip newlines between args: always in paren form, and also when
    # default_count is set (known arg count makes newline skipping safe).
    if !stop_repeatable_at_newline || (syntax.default_count > 0)
      skip_newlines!(stream)
    end
    bare_mask = strip_flags(mask)
    mode = effective_arg_mode(mask, syntax.arg_modes[index])
    if is_repeatable(mask)
      # In non-parenthesized form, limit total args to default_count if set
      max_args = (repeatable_across_newlines || syntax.default_count < 0) ? typemax(Int) : syntax.default_count
      while length(args) < max_args && can_start_argument(stream, bare_mask, model, registry)
        # In non-parenthesized form, don't consume a [ that looks like a
        # command block as a repeatable arg — it likely belongs to the parent.
        if stop_repeatable_at_newline && !isempty(args) && peek(stream).kind == LBracketToken
          if looks_like_command_block(stream, model, registry)
            break
          end
        end
        push!(args, parse_argument(stream, bare_mask, mode, model, registry, scope, expression_min_precedence))
        if stop_repeatable_at_newline
          if check(stream, NewlineToken)
            # Peek past newline: continue only for unambiguous expression starters
            saved_nl = stream.index
            skip_newlines!(stream)
            next_kind = peek(stream).kind
            # When default_count is set and we still need more args, be more
            # permissive — accept any token that can start an argument.
            if max_args < typemax(Int) && length(args) < max_args
              if can_start_argument(stream, bare_mask, model, registry)
                continue
              end
            elseif next_kind in (StringToken, NumberToken, LParenToken) &&
               can_start_argument(stream, bare_mask, model, registry)
              continue
            end
            stream.index = saved_nl
            break
          end
        end
        skip_newlines!(stream)
      end
      continue
    end
    if is_optional(mask) && !can_start_argument(stream, bare_mask, model, registry)
      continue
    end
    push!(args, parse_argument(stream, bare_mask, mode, model, registry, scope, expression_min_precedence))
  end
  args
end

# Peek inside a [ ... ] to check if it starts with a known command,
# indicating it's a command block rather than a list/reporter-block argument.
function looks_like_command_block(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry)
  peek(stream).kind == LBracketToken || return false
  idx = stream.index + 1
  while idx <= length(stream.tokens) && stream.tokens[idx].kind == NewlineToken
    idx += 1
  end
  idx > length(stream.tokens) && return false
  token = stream.tokens[idx]
  token.kind == IdentifierToken || return false
  name = canonical_name(token.lexeme)
  get_command(registry, name) !== nothing && return true
  proc = get(model.procedures, name, nothing)
  proc !== nothing && !proc.is_reporter && return true
  false
end

function can_start_argument(stream::TokenStream, mask::Int,
                            model::Union{ModelSpec,Nothing}=nothing,
                            registry::Union{PrimitiveRegistry,Nothing}=nothing)
  token = peek(stream)
  if compatible(mask, ReporterBlockType)
    return token.kind == LBracketToken
  elseif compatible(mask, CodeBlockType)
    return token.kind == LBracketToken
  elseif compatible(mask, CommandBlockType)
    return token.kind == LBracketToken
  elseif compatible(mask, SymbolType)
    return token.kind == IdentifierToken || token.kind == StringToken
  else
    # For scalar types (NumberType, BooleanType, StringType) that are not
    # also list/agentset/agent-compatible, '[' cannot start a valid value.
    # This prevents optional NumberType args from consuming command blocks.
    if token.kind == LBracketToken && !compatible(mask, ListType) &&
       !compatible(mask, AgentsetType) && !compatible(mask, AgentType)
      return false
    end
    # For optional scalar args, reject identifiers that are known commands.
    # This prevents optional NumberType args from consuming the next statement.
    if token.kind == IdentifierToken && model !== nothing && registry !== nothing
      name = canonical_name(token.lexeme)
      if get_command(registry, name) !== nothing
        return false
      end
      proc = get(model.procedures, name, nothing)
      if proc !== nothing && !proc.is_reporter
        return false
      end
    end
    return can_start_expression(token)
  end
end

function parse_argument(
  stream::TokenStream,
  mask::Int,
  mode::Symbol,
  model::ModelSpec,
  registry::PrimitiveRegistry,
  scope::Set{String},
  expression_min_precedence::Int)
  if mode == :reporter_task
    return parse_reporter_task(stream, model, registry, scope)
  elseif mode == :command_task
    return parse_command_task(stream, model, registry, scope)
  elseif mode == :code_block || compatible(mask, CodeBlockType)
    return parse_code_block(stream, model, registry, scope)
  elseif mode == :reporter_block || compatible(mask, ReporterBlockType)
    return parse_reporter_block(stream, model, registry, scope)
  elseif mode == :block || compatible(mask, CommandBlockType)
    return parse_command_block(stream, model, registry, scope)
  elseif mode == :symbol || compatible(mask, SymbolType)
    token = peek(stream)
    if token.kind == StringToken
      # Accept string literals in symbol position (e.g., gis:apply-raster r "elevation")
      advance!(stream)
      return SymbolArg(canonical_name(token.lexeme), token.span)
    end
    # Handle identifiers starting with '-' (e.g., let -s "")
    if token.kind == OperatorToken && token.lexeme == "-"
      next_idx = stream.index + 1
      if next_idx <= length(stream.tokens) && stream.tokens[next_idx].kind == IdentifierToken
        advance!(stream)  # consume '-'
        ident = advance!(stream)  # consume identifier
        combined = "-" * ident.lexeme
        return SymbolArg(canonical_name(combined), span_union(token.span, ident.span))
      end
    end
    token = expect!(stream, IdentifierToken, "expected identifier")
    return SymbolArg(canonical_name(token.lexeme), token.span)
  else
    return parse_expression(stream, model, registry, scope, expression_min_precedence)
  end
end

function parse_command_block(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  expect!(stream, LBracketToken, "expected '[' to start a command block")
  parse_block(stream, model, registry, scope; terminator=RBracketToken)
end

function parse_code_block(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  start = expect!(stream, LBracketToken, "expected '[' to start a code block")
  depth = 1
  stop = start

  while depth > 0
    token = peek(stream)
    token.kind == EofToken && throw(Diagnostic("expected ']' to end a code block", start.span))
    if token.kind == LBracketToken
      depth += 1
    elseif token.kind == RBracketToken
      depth -= 1
      if depth == 0
        stop = token
        advance!(stream)
        break
      end
    end
    advance!(stream)
  end

  inner_start = start.span.stop + 1
  inner_stop = stop.span.start - 1
  body = inner_stop >= inner_start ? model.source[inner_start:inner_stop] : ""
  parsed_body = body

  try
    body_stream = TokenStream(tokenize(body))
    skip_newlines!(body_stream)
    if !check(body_stream, EofToken)
      saved_index = body_stream.index
      expr = parse_expression(body_stream, model, registry, scope, 0)
      skip_newlines!(body_stream)
      parsed_body =
        check(body_stream, EofToken) ?
        expr :
        begin
          body_stream.index = saved_index
          parse_block(body_stream, model, registry, scope; terminator=EofToken)
        end
    end
  catch err
    err isa Diagnostic || rethrow()
  end

  CodeBlockNode(parsed_body, body, span_union(start.span, stop.span))
end

function try_parse_task_parameters!(stream::TokenStream)
  saved_index = stream.index
  params = String[]

  if check(stream, LBracketToken)
    advance!(stream)
    skip_newlines!(stream)
    while !check(stream, RBracketToken)
      token = peek(stream)
      token.kind == IdentifierToken || (stream.index = saved_index; return nothing)
      push!(params, canonical_name(token.lexeme))
      advance!(stream)
      skip_newlines!(stream)
    end
    expect!(stream, RBracketToken, "expected ']' in anonymous procedure inputs")
    skip_newlines!(stream)
  elseif check(stream, IdentifierToken)
    while check(stream, IdentifierToken)
      push!(params, canonical_name(peek(stream).lexeme))
      advance!(stream)
      skip_newlines!(stream)
    end
  end

  if check(stream, OperatorToken) && peek(stream).lexeme == "-"
    advance!(stream)
    if check(stream, OperatorToken) && peek(stream).lexeme == ">"
      advance!(stream)
      return params
    end
  end

  stream.index = saved_index
  nothing
end

function has_explicit_task_syntax(stream::TokenStream)
  check(stream, LBracketToken) || return false
  saved_index = stream.index
  advance!(stream)
  skip_newlines!(stream)
  result = try_parse_task_parameters!(stream) !== nothing
  stream.index = saved_index
  result
end

function parse_reporter_block(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  start = expect!(stream, LBracketToken, "expected '[' to start a reporter block")
  skip_newlines!(stream)
  params = something(try_parse_task_parameters!(stream), String[])
  task_scope = union(scope, Set(params))
  skip_newlines!(stream)
  expr = parse_expression(stream, model, registry, task_scope, 0)
  skip_newlines!(stream)
  stop = expect!(stream, RBracketToken, "expected ']' to end a reporter block")
  ReporterBlockNode(params, expr, span_union(start.span, stop.span))
end

function parse_reporter_task(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  token = peek(stream)
  if token.kind == LBracketToken
    if has_explicit_task_syntax(stream)
      return parse_anonymous_task_expression(stream, model, registry, scope)
    end
    return parse_reporter_block(stream, model, registry, scope)
  elseif token.kind == IdentifierToken || token.kind == OperatorToken
    advance!(stream)
    return CallableRefNode(canonical_name(token.lexeme), token.span)
  end
  parse_expression(stream, model, registry, scope, 0)
end

function parse_command_task_literal(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  start = expect!(stream, LBracketToken, "expected '[' to start an anonymous command")
  skip_newlines!(stream)
  params = something(try_parse_task_parameters!(stream), String[])
  task_scope = union(scope, Set(params))
  body = parse_block(stream, model, registry, task_scope; terminator=RBracketToken)
  CommandTaskNode(params, body, span_union(start.span, body.span))
end

function parse_command_task(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  token = peek(stream)
  if token.kind == LBracketToken
    if has_explicit_task_syntax(stream)
      return parse_anonymous_task_expression(stream, model, registry, scope)
    end
    return parse_command_task_literal(stream, model, registry, scope)
  elseif token.kind == IdentifierToken || token.kind == OperatorToken
    name = canonical_name(token.lexeme)
    # If the identifier is a variable, always parse as expression
    if identifier_is_variable_like(name, model, scope)
      return parse_expression(stream, model, registry, scope, 0)
    end
    # If the identifier is at the end of the statement (followed by a terminator),
    # treat it as a callable reference (e.g., `foreach list run`)
    saved = stream.index
    advance!(stream)
    nxt = peek(stream)
    if nxt.kind in (EofToken, NewlineToken, RBracketToken, RParenToken)
      return CallableRefNode(name, token.span)
    end
    # Otherwise, it might be a multi-arg reporter/command; parse as expression
    stream.index = saved
  end
  parse_expression(stream, model, registry, scope, 0)
end

identifier_is_variable_like(name::String, model::ModelSpec, scope::Set{String}) =
  name in scope || name in model.globals || name in BUILTIN_VARIABLE_NAMES || has_turtle_breed(model, name) || has_link_breed(model, name)

function command_accepts_zero_inputs(syntax::PrimitiveSyntax)
  min_inputs = syntax.left == VoidType ? 0 : 1
  for mask in syntax.right
    is_repeatable(mask) && return min_inputs == 0
    is_optional(mask) || (min_inputs += 1)
  end
  min_inputs == 0
end

function is_zero_input_command_identifier(name::String, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  identifier_is_variable_like(name, model, scope) && return false

  procedure = get(model.procedures, name, nothing)
  if procedure !== nothing
    return !procedure.is_reporter && isempty(procedure.inputs)
  end

  spec = get_command(registry, name)
  spec !== nothing && return command_accepts_zero_inputs(spec.syntax)
  false
end

function parse_anonymous_task_expression(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  start = expect!(stream, LBracketToken, "expected '[' to start an anonymous procedure")
  skip_newlines!(stream)
  params = try_parse_task_parameters!(stream)
  params === nothing && throw(Diagnostic("expected anonymous procedure inputs", peek(stream).span))
  task_scope = union(scope, Set(params))
  skip_newlines!(stream)
  body_start = stream.index

  try
    expr = parse_expression(stream, model, registry, task_scope, 0)
    skip_newlines!(stream)
    if check(stream, RBracketToken) &&
       !(expr isa VariableRef && is_zero_input_command_identifier(expr.name, model, registry, task_scope))
      stop = expect!(stream, RBracketToken, "expected ']' to end an anonymous reporter")
      return ReporterBlockNode(params, expr, span_union(start.span, stop.span))
    end
  catch err
    err isa Diagnostic || rethrow()
  end

  stream.index = body_start
  body = parse_block(stream, model, registry, task_scope; terminator=RBracketToken)
  CommandTaskNode(params, body, span_union(start.span, body.span))
end

function parse_ifelse_value_call(stream::TokenStream, token::Token, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  args = Any[]
  skip_newlines!(stream)
  push!(args, parse_expression(stream, model, registry, scope, 0))
  skip_newlines!(stream)
  push!(args, parse_reporter_block(stream, model, registry, scope))
  skip_newlines!(stream)

  while peek(stream).kind ∉ (EofToken, RBracketToken, RParenToken, CommaToken)
    if check(stream, NewlineToken)
      # Peek past newlines to see if there's another block or condition
      saved = stream.index
      skip_newlines!(stream)
      if !check(stream, LBracketToken) && !can_start_expression(peek(stream))
        stream.index = saved
        break
      end
    end
    if check(stream, LBracketToken)
      push!(args, parse_reporter_block(stream, model, registry, scope))
      break
    end
    push!(args, parse_expression(stream, model, registry, scope, 0))
    skip_newlines!(stream)
    push!(args, parse_reporter_block(stream, model, registry, scope))
    skip_newlines!(stream)
  end

  ReporterCall("IFELSE-VALUE", args, span_union(token.span, spanof(last(args))))
end

function is_content_reporter_block(stream::TokenStream, registry::PrimitiveRegistry)
  index = stream.index
  if index > length(stream.tokens) || stream.tokens[index].kind != LBracketToken
    return false
  end
  index += 1
  while index <= length(stream.tokens) && stream.tokens[index].kind == NewlineToken
    index += 1
  end
  if index > length(stream.tokens)
    return false
  end
  first_token = stream.tokens[index]
  if first_token.kind == IdentifierToken
    name = canonical_name(first_token.lexeme)
    name in ("TRUE", "FALSE", "NOBODY") && return false
    spec = get_reporter(registry, name)
    spec !== nothing && return true
    cmd = get_command(registry, name)
    cmd !== nothing && return true
  end
  false
end

function is_infix_reporter_block(stream::TokenStream, registry::PrimitiveRegistry)
  depth = 0
  index = stream.index

  while index <= length(stream.tokens)
    token = stream.tokens[index]
    if token.kind == LBracketToken
      depth += 1
    elseif token.kind == RBracketToken
      depth -= 1
      if depth == 0
        index += 1
        while index <= length(stream.tokens) && stream.tokens[index].kind == NewlineToken
          index += 1
        end
        if index > length(stream.tokens)
          return false
        end
        follower = stream.tokens[index]
        if follower.kind == IdentifierToken || follower.kind == OperatorToken
          spec = get_reporter(registry, canonical_name(follower.lexeme))
          return spec !== nothing && compatible(spec.syntax.left, ReporterBlockType)
        end
        return false
      end
    end
    index += 1
  end

  false
end

function parse_list_literal_item(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  token = peek(stream)
  if token.kind == NumberToken
    advance!(stream)
    return NumberLiteral(Float64(token.value), token.span)
  elseif token.kind == StringToken
    advance!(stream)
    return StringLiteral(String(token.value), token.span)
  elseif token.kind == LBracketToken
    return parse_list_literal(stream, model, registry, scope)
  elseif token.kind == OperatorToken && token.lexeme == "-"
    advance!(stream)
    nxt = peek(stream)
    if nxt.kind == NumberToken
      advance!(stream)
      return NumberLiteral(-Float64(nxt.value), span_union(token.span, nxt.span))
    end
    throw(Diagnostic("expected number after '-' in list literal", token.span))
  elseif token.kind == IdentifierToken
    uname = uppercase(token.lexeme)
    if uname == "TRUE"
      advance!(stream)
      return BoolLiteral(true, token.span)
    elseif uname == "FALSE"
      advance!(stream)
      return BoolLiteral(false, token.span)
    elseif uname == "NOBODY"
      advance!(stream)
      return NobodyLiteral(token.span)
    end
    # Accept identifiers as variable references in list literals
    # (e.g., color constants like white, red, or other variables)
    advance!(stream)
    return VariableRef(canonical_name(token.lexeme), token.span, false)
  elseif token.kind == LParenToken
    # Accept parenthesized expressions in list literals (e.g., [(red)])
    return parse_expression(stream, model, registry, scope, 0)
  end
  throw(Diagnostic("expected literal value in list (number, string, boolean, or nested list)", token.span))
end

function starts_list_literal_item(stream::TokenStream)
  token = peek(stream)
  token.kind == NumberToken && return true
  token.kind == StringToken && return true
  token.kind == LBracketToken && return true
  if token.kind == OperatorToken && token.lexeme == "-"
    idx = stream.index + 1
    return idx <= length(stream.tokens) && stream.tokens[idx].kind == NumberToken
  end
  if token.kind == IdentifierToken
    uname = uppercase(token.lexeme)
    return uname == "TRUE" || uname == "FALSE"
  end
  false
end

function parse_list_literal(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  start = expect!(stream, LBracketToken, "expected '['")
  skip_newlines!(stream)
  items = AbstractExpr[]
  if check(stream, RBracketToken)
    # empty list
  elseif starts_list_literal_item(stream)
    # strict literal-only parsing (fixes [-1 -1] → two numbers, not subtraction)
    while !check(stream, RBracketToken)
      push!(items, parse_list_literal_item(stream, model, registry, scope))
      skip_newlines!(stream)
    end
  else
    # fallback: expression parsing (for [list ...] etc. that look like list literals
    # but actually contain reporter expressions — legacy compatibility)
    while !check(stream, RBracketToken)
      push!(items, parse_expression(stream, model, registry, scope, 0))
      skip_newlines!(stream)
    end
  end
  stop = expect!(stream, RBracketToken, "expected ']'")
  ListLiteral(items, span_union(start.span, stop.span))
end

function parse_expression(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String}, min_precedence::Int)
  left = parse_prefix(stream, model, registry, scope)
  while true
    token = peek(stream)
    if token.kind in (EofToken, RBracketToken, RParenToken, CommaToken)
      break
    end

    # At newlines, check if the next non-newline token is an infix operator;
    # if so, continue the expression across the line break.
    if token.kind == NewlineToken
      saved_index = stream.index
      skip_newlines!(stream)
      nxt = peek(stream)
      is_continuation = false
      if nxt.kind == OperatorToken || nxt.kind == IdentifierToken
        nxt_name = canonical_name(nxt.lexeme)
        nxt_spec = get_reporter(registry, nxt_name)
        if nxt_spec !== nothing && nxt_spec.syntax.left != VoidType && nxt_spec.syntax.precedence >= min_precedence
          is_continuation = true
        end
      end
      if !is_continuation
        stream.index = saved_index
        break
      end
      token = peek(stream)
    end

    op_name =
      if token.kind == OperatorToken || token.kind == IdentifierToken
        canonical_name(token.lexeme)
      else
        break
      end

    spec = get_reporter(registry, op_name)
    if spec === nothing || spec.syntax.left == VoidType || spec.syntax.precedence < min_precedence
      break
    end

    advance!(stream)
    modes = copy(spec.syntax.arg_modes)
    if length(modes) < length(spec.syntax.right)
      append!(modes, fill(:eval, length(spec.syntax.right) - length(modes)))
    end

    # OF is right-associative so chained `[x] of [y] of z` parses as `[x] of ([y] of z)`
    right_min_prec = op_name == "OF" ? spec.syntax.precedence : spec.syntax.precedence + 1

    args = Any[left]
    skip_newlines!(stream)
    for (index, mask) in enumerate(spec.syntax.right)
      bare_mask = strip_flags(mask)
      mode = effective_arg_mode(mask, modes[index])
      if is_repeatable(mask)
        while can_start_argument(stream, bare_mask, model, registry)
          push!(args, parse_argument(stream, bare_mask, mode, model, registry, scope, right_min_prec))
          check(stream, NewlineToken) && break
          skip_newlines!(stream)
        end
        continue
      elseif is_optional(mask) && !can_start_argument(stream, bare_mask, model, registry)
        continue
      end
      push!(args, parse_argument(stream, bare_mask, mode, model, registry, scope, right_min_prec))
      # Only skip newlines between arguments, not after the last one;
      # the main expression loop handles newline continuation decisions.
      if index < length(spec.syntax.right)
        skip_newlines!(stream)
      end
    end

    left = ReporterCall(op_name, args, span_union(spanof(left), spanof(last(args))))
  end
  left
end

function parse_prefix(stream::TokenStream, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  token = peek(stream)

  if token.kind == NumberToken
    advance!(stream)
    return NumberLiteral(Float64(token.value), token.span)
  elseif token.kind == StringToken
    advance!(stream)
    return StringLiteral(String(token.value), token.span)
  elseif token.kind == LParenToken
    advance!(stream)
    skip_newlines!(stream)
    expr = parse_expression(stream, model, registry, scope, 0)
    skip_newlines!(stream)
    # Check for variadic: if expr is a ReporterCall and there are more expressions before )
    if expr isa ReporterCall && !check(stream, RParenToken)
      extra_args = Any[]
      while !check(stream, RParenToken) && !check(stream, EofToken)
        skip_newlines!(stream)
        check(stream, RParenToken) && break
        push!(extra_args, parse_expression(stream, model, registry, scope, 0))
        skip_newlines!(stream)
      end
      append!(expr.args, extra_args)
      expr = ReporterCall(expr.name, expr.args, span_union(token.span, peek(stream).span))
    end
    expect!(stream, RParenToken, "expected ')'")
    return expr
  elseif token.kind == LBracketToken
    return has_explicit_task_syntax(stream) ?
      parse_anonymous_task_expression(stream, model, registry, scope) :
      is_infix_reporter_block(stream, registry) ?
      parse_reporter_block(stream, model, registry, scope) :
      parse_list_literal(stream, model, registry, scope)
  elseif token.kind == OperatorToken && token.lexeme == "-"
    # Check if -identifier is a variable name in scope (e.g., let -s "")
    next_idx = stream.index + 1
    if next_idx <= length(stream.tokens) && stream.tokens[next_idx].kind == IdentifierToken
      combined = "-" * stream.tokens[next_idx].lexeme
      cname = canonical_name(combined)
      if identifier_is_variable_like(cname, model, scope)
        advance!(stream)  # consume '-'
        ident = advance!(stream)  # consume identifier
        return VariableRef(cname, span_union(token.span, ident.span), false)
      end
    end
    advance!(stream)
    expr = parse_expression(stream, model, registry, scope, PrefixPrecedence)
    return UnaryExpr("-", expr, span_union(token.span, spanof(expr)))
  elseif token.kind != IdentifierToken
    throw(Diagnostic("expected expression", token.span))
  end

  name = canonical_name(token.lexeme)

  if name == "TRUE"
    advance!(stream)
    return BoolLiteral(true, token.span)
  elseif name == "FALSE"
    advance!(stream)
    return BoolLiteral(false, token.span)
  elseif name == "NOBODY"
    advance!(stream)
    return NobodyLiteral(token.span)
  elseif name == "IFELSE-VALUE" || name == "IF-ELSE-VALUE"
    advance!(stream)
    return parse_ifelse_value_call(stream, token, model, registry, scope)
  end

  dynamic_breed_predicate = parse_dynamic_breed_predicate(name, token, stream, model, registry, scope)
  dynamic_breed_predicate !== nothing && return dynamic_breed_predicate

  dynamic_turtle_breed_reporter = parse_dynamic_turtle_breed_reporter(name, token, stream, model, registry, scope)
  dynamic_turtle_breed_reporter !== nothing && return dynamic_turtle_breed_reporter

  dynamic_link_relation_reporter = parse_dynamic_link_relation_reporter(name, token, stream, model, registry, scope)
  dynamic_link_relation_reporter !== nothing && return dynamic_link_relation_reporter

  dynamic_link_neighbor_reporter = parse_dynamic_link_neighbor_reporter(name, token, stream, model, registry, scope)
  dynamic_link_neighbor_reporter !== nothing && return dynamic_link_neighbor_reporter

  dynamic_link_lookup_reporter = parse_dynamic_link_lookup_reporter(name, token, stream, model, registry, scope)
  dynamic_link_lookup_reporter !== nothing && return dynamic_link_lookup_reporter

  if name in scope || name in model.globals || name in BUILTIN_VARIABLE_NAMES || has_turtle_breed(model, name) || has_link_breed(model, name)
    advance!(stream)
    return VariableRef(name, token.span, name in scope)
  end

  dynamic_link_reporter = parse_dynamic_link_reporter(name, token, model)
  if dynamic_link_reporter !== nothing
    advance!(stream)
    return dynamic_link_reporter
  end

  dynamic_turtle_on_reporter = parse_dynamic_turtle_on_reporter(name, token, stream, model, registry, scope)
  dynamic_turtle_on_reporter !== nothing && return dynamic_turtle_on_reporter

  dynamic_turtle_here_reporter = parse_dynamic_turtle_here_reporter(name, token, stream, model, registry, scope)
  dynamic_turtle_here_reporter !== nothing && return dynamic_turtle_here_reporter

  dynamic_turtle_at_reporter = parse_dynamic_turtle_at_reporter(name, token, stream, model, registry, scope)
  dynamic_turtle_at_reporter !== nothing && return dynamic_turtle_at_reporter

  procedure = get(model.procedures, name, nothing)
  if procedure !== nothing && procedure.is_reporter
    advance!(stream)
    args = Any[]
    for (i, _) in enumerate(procedure.inputs)
      # Skip newlines between args; for the first arg, only skip if a clear
      # expression starter follows (prevents consuming the next statement).
      if i > 1
        skip_newlines!(stream)
      elseif check(stream, NewlineToken)
        saved = stream.index
        skip_newlines!(stream)
        nxt = peek(stream).kind
        if !(nxt in (LParenToken, NumberToken, StringToken, LBracketToken))
          stream.index = saved
        end
      end
      push!(args, parse_expression(stream, model, registry, scope, PrefixPrecedence))
    end
    last_span = isempty(args) ? token.span : spanof(last(args))
    return ReporterCall(name, args, span_union(token.span, last_span))
  end

  spec = get_reporter(registry, name)
  if spec !== nothing && spec.syntax.left == VoidType
    advance!(stream)
    args = parse_call_arguments(
      stream, spec.syntax, model, registry, scope;
      expression_min_precedence=PrefixPrecedence,
      repeatable_across_newlines=false)
    last_span = isempty(args) ? token.span : spanof(last(args))
    return ReporterCall(name, args, span_union(token.span, last_span))
  end

  advance!(stream)
  VariableRef(name, token.span, false)
end

# ─── .nlogox (NetLogo 7 XML format) parsing ─────────────────────────────────

function is_nlogox_source(source::String)::Bool
  s = lstrip(source)
  startswith(s, "<?xml") || startswith(s, "<model")
end

function xml_attr(node, name::String, default::String="")
  haskey(node, name) ? node[name] : default
end

function xml_attr_int(node, name::String, default::Int=0)
  haskey(node, name) ? parse(Int, node[name]) : default
end

function xml_attr_float(node, name::String, default::Float64=0.0)
  haskey(node, name) ? parse(Float64, node[name]) : default
end

function xml_attr_bool(node, name::String, default::Bool=false)
  haskey(node, name) ? lowercase(node[name]) == "true" : default
end

function xml_text_content(node)
  buf = IOBuffer()
  for child in eachnode(node)
    if EzXML.istext(child) || EzXML.iscdata(child)
      print(buf, EzXML.nodecontent(child))
    end
  end
  String(take!(buf))
end

function xml_child_text(parent, tag::String)
  for child in eachelement(parent)
    if EzXML.nodename(child) == tag
      return xml_text_content(child)
    end
  end
  ""
end

function xml_bounds(node)
  x = xml_attr_int(node, "x", 0)
  y = xml_attr_int(node, "y", 0)
  w = xml_attr_int(node, "width", 100)
  h = xml_attr_int(node, "height", 100)
  (x, y, x + w, y + h)
end

function parse_xml_view(node)
  x = xml_attr_int(node, "x", 0)
  y = xml_attr_int(node, "y", 0)
  w = xml_attr_int(node, "width", 400)
  h = xml_attr_int(node, "height", 400)
  ViewWidgetSpec(
    x, y, x + w, y + h,
    xml_attr_float(node, "patchSize", 13.0),
    xml_attr_int(node, "fontSize", 10),
    xml_attr_bool(node, "wrappingAllowedX", false),
    xml_attr_bool(node, "wrappingAllowedY", false),
    xml_attr_int(node, "minPxcor", -16),
    xml_attr_int(node, "maxPxcor", 16),
    xml_attr_int(node, "minPycor", -16),
    xml_attr_int(node, "maxPycor", 16),
    xml_attr_bool(node, "showTickCounter", true),
    xml_attr(node, "tickCounterLabel", "ticks"),
    xml_attr_float(node, "frameRate", 30.0))
end

function parse_xml_slider(node)
  left, top, right, bottom = xml_bounds(node)
  variable = xml_attr(node, "variable", "")
  SliderWidgetSpec(
    left, top, right, bottom,
    xml_attr(node, "display", variable),
    variable,
    xml_attr(node, "min", "0"),
    xml_attr(node, "max", "100"),
    xml_attr_float(node, "default", 0.0),
    xml_attr(node, "step", "1"),
    xml_attr(node, "units", ""),
    xml_attr(node, "direction", "HORIZONTAL"))
end

function parse_xml_switch(node)
  left, top, right, bottom = xml_bounds(node)
  variable = xml_attr(node, "variable", "")
  SwitchWidgetSpec(
    left, top, right, bottom,
    xml_attr(node, "display", variable),
    variable,
    xml_attr_bool(node, "on", false))
end

function parse_xml_chooser(node)
  left, top, right, bottom = xml_bounds(node)
  variable = xml_attr(node, "variable", "")
  choices = Any[]
  for child in eachelement(node)
    if EzXML.nodename(child) == "choice"
      ctype = xml_attr(child, "type", "string")
      cval = xml_attr(child, "value", "")
      if ctype == "number"
        push!(choices, parse(Float64, cval))
      elseif ctype == "boolean"
        push!(choices, lowercase(cval) == "true")
      else
        push!(choices, cval)
      end
    end
  end
  current = xml_attr_int(node, "current", 0)
  if !isempty(choices)
    current = clamp(current, 0, length(choices) - 1)
  end
  ChooserWidgetSpec(
    left, top, right, bottom,
    xml_attr(node, "display", variable),
    variable,
    choices,
    current)
end

function parse_xml_input(node)
  left, top, right, bottom = xml_bounds(node)
  variable = xml_attr(node, "variable", "")
  value_kind_raw = xml_attr(node, "type", "String")
  value_kind = uppercase(first(value_kind_raw)) * value_kind_raw[2:end]
  if value_kind == "Num" || value_kind == "NUMBER"
    value_kind = "Number"
  end
  multiline = xml_attr_bool(node, "multiline", false)
  raw_value = xml_text_content(node)
  value_child = nothing
  for child in eachelement(node)
    if EzXML.nodename(child) == "value"
      value_child = xml_text_content(child)
      break
    end
  end
  raw_str = value_child !== nothing ? value_child : raw_value
  value::Any =
    if value_kind == "Number" || value_kind == "Color"
      isempty(strip(raw_str)) ? 0.0 : parse(Float64, strip(raw_str))
    else
      raw_str
    end
  InputBoxWidgetSpec(
    left, top, right, bottom,
    variable,
    value,
    multiline,
    value_kind)
end

function parse_xml_monitor(node)
  left, top, right, bottom = xml_bounds(node)
  source = strip(xml_text_content(node))
  MonitorWidgetSpec(
    left, top, right, bottom,
    xml_attr(node, "display", ""),
    source,
    xml_attr_int(node, "precision", 17),
    xml_attr_int(node, "fontSize", 11))
end

function parse_xml_button(node)
  left, top, right, bottom = xml_bounds(node)
  source = strip(xml_text_content(node))
  display = xml_attr(node, "display", "")
  if isempty(display)
    display = source
  end
  kind_raw = xml_attr(node, "kind", "Observer")
  kind = uppercase(kind_raw)
  if !(kind in ("OBSERVER", "TURTLE", "PATCH", "LINK"))
    kind = "OBSERVER"
  end
  ButtonWidgetSpec(
    left, top, right, bottom,
    display,
    source,
    xml_attr_bool(node, "forever", false),
    kind,
    nothing,
    xml_attr_bool(node, "disableUntilTicks", false))
end

function parse_xml_pen(node)
  PlotPenSpec(
    xml_attr(node, "display", "default"),
    parse(Int, xml_attr(node, "color", "-16777216")),
    xml_attr_float(node, "interval", 1.0),
    xml_attr_int(node, "mode", 0),
    xml_attr_bool(node, "legend", true),
    xml_child_text(node, "setup"),
    xml_child_text(node, "update"))
end

function parse_xml_plot(node)
  left, top, right, bottom = xml_bounds(node)
  pens = PlotPenSpec[]
  setup_code = ""
  update_code = ""
  for child in eachelement(node)
    tag = EzXML.nodename(child)
    if tag == "pen"
      push!(pens, parse_xml_pen(child))
    elseif tag == "setup"
      setup_code = xml_text_content(child)
    elseif tag == "update"
      update_code = xml_text_content(child)
    end
  end
  auto_plot_x = xml_attr_bool(node, "autoPlotX", true)
  auto_plot_y = xml_attr_bool(node, "autoPlotY", true)
  PlotSpec(
    xml_attr(node, "display", ""),
    xml_attr(node, "xAxis", ""),
    xml_attr(node, "yAxis", ""),
    xml_attr_float(node, "xMin", 0.0),
    xml_attr_float(node, "xMax", 10.0),
    xml_attr_float(node, "yMin", 0.0),
    xml_attr_float(node, "yMax", 10.0),
    auto_plot_x,
    auto_plot_y,
    xml_attr_bool(node, "legend", false),
    setup_code,
    update_code,
    pens)
end

function parse_xml_note(node)
  left, top, right, bottom = xml_bounds(node)
  TextBoxWidgetSpec(
    left, top, right, bottom,
    xml_text_content(node),
    xml_attr_int(node, "fontSize", 12),
    xml_attr_float(node, "color", 0.0),
    xml_attr_bool(node, "transparent", true))
end

function parse_xml_output(node)
  left, top, right, bottom = xml_bounds(node)
  OutputWidgetSpec(left, top, right, bottom, xml_attr_int(node, "fontSize", 12))
end

function xml_turtle_shapes_to_text(shapes_node)
  buf = IOBuffer()
  for shape_el in eachelement(shapes_node)
    EzXML.nodename(shape_el) == "shape" || continue
    name = xml_attr(shape_el, "name", "default")
    rotatable = xml_attr(shape_el, "rotatable", "true")
    editable_idx = xml_attr(shape_el, "editableColorIndex", "0")
    println(buf, name)
    println(buf, rotatable)
    println(buf, editable_idx)
    for elem in eachelement(shape_el)
      tag = EzXML.nodename(elem)
      if tag == "polygon"
        color = xml_attr(elem, "color", "0")
        filled = xml_attr(elem, "filled", "true")
        marked = xml_attr(elem, "marked", "true")
        points_parts = String[]
        for pt in eachelement(elem)
          EzXML.nodename(pt) == "point" || continue
          push!(points_parts, xml_attr(pt, "x", "0"))
          push!(points_parts, xml_attr(pt, "y", "0"))
        end
        println(buf, "Polygon $color $filled $marked $(join(points_parts, " "))")
      elseif tag == "circle"
        color = xml_attr(elem, "color", "0")
        filled = xml_attr(elem, "filled", "true")
        marked = xml_attr(elem, "marked", "true")
        x = xml_attr(elem, "x", "0")
        y = xml_attr(elem, "y", "0")
        diameter = xml_attr(elem, "diameter", "0")
        println(buf, "Circle $color $filled $marked $x $y $diameter")
      elseif tag == "rectangle"
        color = xml_attr(elem, "color", "0")
        filled = xml_attr(elem, "filled", "true")
        marked = xml_attr(elem, "marked", "true")
        x1 = xml_attr(elem, "startX", "0")
        y1 = xml_attr(elem, "startY", "0")
        x2 = xml_attr(elem, "endX", "0")
        y2 = xml_attr(elem, "endY", "0")
        println(buf, "Rectangle $color $filled $marked $x1 $y1 $x2 $y2")
      elseif tag == "line"
        color = xml_attr(elem, "color", "0")
        marked = xml_attr(elem, "marked", "true")
        sx = xml_attr(elem, "startX", "0")
        sy = xml_attr(elem, "startY", "0")
        ex = xml_attr(elem, "endX", "0")
        ey = xml_attr(elem, "endY", "0")
        println(buf, "Line $color $marked $sx $sy $ex $ey")
      end
    end
    println(buf)
  end
  String(take!(buf))
end

function parse_nlogox_widgets!(model::ModelSpec, widgets_node)
  empty!(model.plots)
  empty!(model.interface_widgets)
  empty!(model.interface_globals)
  model.view_widget = nothing
  for child in eachelement(widgets_node)
    tag = EzXML.nodename(child)
    if tag == "view"
      view = parse_xml_view(child)
      push!(model.interface_widgets, view)
      model.view_widget = view
    elseif tag == "slider"
      widget = parse_xml_slider(child)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif tag == "switch"
      widget = parse_xml_switch(child)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif tag == "chooser"
      widget = parse_xml_chooser(child)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif tag == "input"
      widget = parse_xml_input(child)
      push!(model.interface_widgets, widget)
      register_interface_global!(model, widget)
    elseif tag == "monitor"
      push!(model.interface_widgets, parse_xml_monitor(child))
    elseif tag == "button"
      push!(model.interface_widgets, parse_xml_button(child))
    elseif tag == "plot"
      push!(model.plots, parse_xml_plot(child))
    elseif tag == "note"
      push!(model.interface_widgets, parse_xml_note(child))
    elseif tag == "output"
      push!(model.interface_widgets, parse_xml_output(child))
    end
  end
  nothing
end

function parse_nlogox_model(
  source::String,
  registry::PrimitiveRegistry;
  source_path::Union{Nothing, AbstractString}=nothing,
  extension_host::Module=Main)

  doc = EzXML.parsexml(source)
  root = EzXML.root(doc)

  # Extract code
  code_source = ""
  for child in eachelement(root)
    if EzXML.nodename(child) == "code"
      code_source = xml_text_content(child)
      break
    end
  end

  # Handle includes
  include_specs = collect_model_include_specs(code_source)
  if source_path !== nothing && !isempty(include_specs)
    code_source = expand_model_included_code(code_source, source_path; include_specs=include_specs)
  elseif source_path === nothing && !isempty(include_specs)
    throw(Diagnostic("Can't resolve __includes without a source path", last(first(include_specs))))
  end

  stream = TokenStream(tokenize(code_source))
  model = ModelSpec(source)
  model.has_interface_section = true
  model.source_path = source_path === nothing ? nothing : String(source_path)
  raw_procedures = RawProcedure[]
  extension_specs = Pair{String, SourceSpan}[]

  while !check(stream, EofToken)
    skip_newlines!(stream)
    check(stream, EofToken) && break
    token = expect!(stream, IdentifierToken, "expected a declaration or procedure")
    name = canonical_name(token.lexeme)

    if name == "GLOBALS"
      append!(model.globals, parse_identifier_list(stream))
    elseif name == "TURTLES-OWN"
      append!(model.turtles_own, parse_identifier_list(stream))
    elseif name == "PATCHES-OWN"
      append!(model.patches_own, parse_identifier_list(stream))
    elseif name == "LINKS-OWN"
      append!(model.links_own, parse_identifier_list(stream))
    elseif name == "BREED"
      parse_breed_declaration!(model, stream; is_link_breed=false, directed=false)
    elseif name == "DIRECTED-LINK-BREED"
      parse_breed_declaration!(model, stream; is_link_breed=true, directed=true)
    elseif name == "UNDIRECTED-LINK-BREED"
      parse_breed_declaration!(model, stream; is_link_breed=true, directed=false)
    elseif endswith(name, "-OWN")
      parse_breed_own_declaration!(model, name, stream, token)
    elseif name == "EXTENSIONS"
      specs = parse_extension_name_list(stream)
      append!(model.extensions, first.(specs))
      append!(extension_specs, specs)
    elseif is_include_declaration(name)
      append!(model.includes, first.(parse_include_path_list(stream)))
    elseif name == "TO" || name == "TO-REPORT"
      push!(raw_procedures, parse_raw_procedure!(stream, token))
    else
      throw(Diagnostic("unknown top-level form $(token.lexeme)", token.span))
    end
    skip_newlines!(stream)
  end

  load_extensions!(registry, extension_specs; host_module=extension_host)

  for raw in raw_procedures
    model.procedures[raw.name] = ProcedureSpec(raw.name, raw.is_reporter, raw.inputs, BlockNode(AbstractStmt[], raw.span), raw.span)
    push!(model.procedure_order, raw.name)
  end

  # Parse widgets from XML
  for child in eachelement(root)
    tag = EzXML.nodename(child)
    if tag == "widgets"
      parse_nlogox_widgets!(model, child)
    elseif tag == "turtleShapes"
      model.turtle_shapes_text = xml_turtle_shapes_to_text(child)
    end
  end

  for raw in raw_procedures
    body = parse_procedure_body(raw, model, registry)
    model.procedures[raw.name] = ProcedureSpec(raw.name, raw.is_reporter, raw.inputs, body, raw.span)
  end

  validate_plot_specs!(model, registry)
  validate_interface_widgets!(model, registry)
  model
end
