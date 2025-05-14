enum RefAccessType { watch, read, listen }


class ProviderEdge {
  final String from;
  final String to;
  final String file;
  final int line;
  final RefAccessType type;


  ProviderEdge(this.from, this.to, this.file, this.line, this.type);
}