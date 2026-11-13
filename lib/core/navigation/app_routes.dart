/// Every route path in one place, so no screen hard-codes URLs.
abstract final class AppRoutes {
  static const home = '/home';
  static const brain = '/brain';
  static const capture = '/capture';
  static const ask = '/ask';
  static const search = '/search';
  static const digest = '/digest';
  static const tasks = '/tasks';
  static const settings = '/settings';

  static const memoryPattern = '/memory/:id';
  static const collectionPattern = '/collection/:id';
  static const idParam = 'id';

  static String memory(String id) => '/memory/$id';

  static String collection(String id) => '/collection/$id';
}
