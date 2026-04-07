struct SourceSpan
  start::Int
  stop::Int
  line::Int
  column::Int
end

SourceSpan() = SourceSpan(0, 0, 1, 1)

struct Diagnostic <: Exception
  message::String
  span::SourceSpan
end

Base.showerror(io::IO, diagnostic::Diagnostic) =
  print(io, diagnostic.message, " at line ", diagnostic.span.line, ", column ", diagnostic.span.column)

span_union(a::SourceSpan, b::SourceSpan) =
  SourceSpan(min(a.start, b.start), max(a.stop, b.stop), a.line, a.column)
