import 'mapkit_initializer_stub.dart'
    if (dart.library.io) 'mapkit_initializer_io.dart' as impl;

Future<void> initializeMapkit(String apiKey) => impl.initializeMapkit(apiKey);
