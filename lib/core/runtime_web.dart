import 'package:web/web.dart' as web;

bool get canPersistSession => web.window.isSecureContext;
