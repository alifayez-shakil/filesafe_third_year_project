class FileResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  const FileResponse.ok(this.data) : success = true, error = null;
  const FileResponse.fail(this.error) : success = false, data = null;

  bool get isOk => success;

  FileResponse<R> map<R>(R Function(T data) transform) {
    if (success && data != null) {
      return FileResponse.ok(transform(data as T));
    }
    return FileResponse.fail(error);
  }
}
