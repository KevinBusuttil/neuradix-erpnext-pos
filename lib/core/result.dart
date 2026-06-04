/// A minimal Result type for operations that can fail without throwing.
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) ok,
    required R Function(Object error, StackTrace? stack) err,
  }) {
    final self = this;
    return switch (self) {
      Ok<T>() => ok(self.value),
      Err<T>() => err(self.error, self.stack),
    };
  }

  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
  bool get isOk => this is Ok<T>;
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.error, [this.stack]);
  final Object error;
  final StackTrace? stack;
}
