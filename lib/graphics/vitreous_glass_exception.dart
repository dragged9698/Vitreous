/// Thrown when a Vitreous shader fails to compile, bind, or accept uniforms.
class VitreousGlassException implements Exception {
  VitreousGlassException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    final extra = cause != null ? ' (cause: $cause)' : '';
    return 'VitreousGlassException: $message$extra';
  }
}
