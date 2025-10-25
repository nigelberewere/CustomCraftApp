import 'package:get_it/get_it.dart';
import 'attendance_cache_service.dart';
import 'pdf_service.dart';
import 'project_service.dart';
import 'quotation_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Register services as lazy singletons.
  // They will be instantiated only when they are first requested.
  getIt.registerLazySingleton(() => ProjectService());
  getIt.registerLazySingleton(() => QuotationService());
  getIt.registerLazySingleton(() => PdfService());

  // Register the existing singleton instance of the cache service.
  getIt.registerLazySingleton(() => AttendanceCacheService.instance);
}
