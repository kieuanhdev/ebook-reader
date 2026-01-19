import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'injection.config.dart'; // File này chưa có, sẽ được sinh ra ở Bước 4

// Khởi tạo đối tượng GetIt (Service Locator)
final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init', // tên hàm sinh ra mặc định
  preferRelativeImports: true, // dùng import tương đối cho gọn
  asExtension: true, // dùng extension method .init()
)
void configureDependencies() => getIt.init();
