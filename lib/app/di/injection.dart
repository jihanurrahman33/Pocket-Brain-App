import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_logger.dart';
import '../../core/usecase/usecase.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../data/datasources/ai/on_device_ai_runtime.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/json_file_export_repository.dart';
import '../../data/repositories/on_device_model_repository.dart';
import '../../data/repositories/prefs_preferences_repository.dart';
import '../../data/repositories/sqlite_collection_repository.dart';
import '../../data/repositories/sqlite_conversation_repository.dart';
import '../../data/repositories/sqlite_memory_repository.dart';
import '../../data/repositories/sqlite_task_repository.dart';
import '../../data/services/ai/generation_services.dart';
import '../../data/services/ai/memory_analyzers.dart';
import '../../data/services/web/http_link_reader.dart';
import '../../domain/entities/search.dart';
import '../../domain/repositories/collection_repository.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../domain/repositories/data_export_repository.dart';
import '../../domain/repositories/memory_repository.dart';
import '../../domain/repositories/model_repository.dart';
import '../../domain/repositories/preferences_repository.dart';
import '../../domain/repositories/search_history_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/services/ai_services.dart';
import '../../domain/services/relevance_scorer.dart';
import '../../domain/usecases/ask/ask_usecases.dart';
import '../../domain/usecases/capture/capture_usecases.dart';
import '../../domain/usecases/collections/collection_usecases.dart';
import '../../domain/usecases/indexing/indexing_usecases.dart';
import '../../domain/usecases/memories/memory_usecases.dart';
import '../../domain/usecases/models/model_usecases.dart';
import '../../domain/usecases/recall/recall_usecases.dart';
import '../../domain/usecases/search/search_usecases.dart';
import '../../domain/usecases/settings/settings_usecases.dart';
import '../../domain/usecases/tasks/task_usecases.dart';
import '../../features/ask/bloc/ask_bloc.dart';
import '../../features/capture/bloc/capture_bloc.dart';
import '../../features/collections/bloc/collection_cubit.dart';
import '../../features/digest/bloc/digest_cubit.dart';
import '../../features/home/bloc/home_cubit.dart';
import '../../features/library/bloc/library_cubit.dart';
import '../../features/memory_detail/bloc/memory_detail_cubit.dart';
import '../../features/model_manager/bloc/model_bloc.dart';
import '../../features/search/bloc/search_bloc.dart';
import '../../features/settings/bloc/settings_cubit.dart';
import '../../features/tasks/bloc/tasks_cubit.dart';

/// The app's service locator.
final sl = GetIt.instance;

/// Platform resources created at startup (or replaced by fakes in tests).
class Infrastructure {
  const Infrastructure({
    required this.database,
    required this.preferences,
    required this.aiRuntime,
    required this.httpClient,
    this.exporter = const JsonFileExportRepository(),
    this.logger = const DebugAppLogger(),
    this.clock = const SystemClock(),
  });

  final AppDatabase database;
  final SharedPreferences preferences;
  final OnDeviceAiRuntime aiRuntime;
  final http.Client httpClient;
  final DataExportRepository exporter;
  final AppLogger logger;
  final Clock clock;
}

/// Composition root: the only place that knows concrete classes. Every
/// other layer depends on abstractions (Dependency Inversion).
Future<void> configureDependencies(Infrastructure infra) async {
  await sl.reset();
  _registerCore(infra);
  _registerRepositories(infra);
  _registerServices();
  _registerUseCases();
  _registerPresentation();
}

void _registerCore(Infrastructure infra) {
  sl
    ..registerSingleton<AppLogger>(infra.logger)
    ..registerSingleton<Clock>(infra.clock)
    ..registerSingleton<IdGenerator>(const UuidIdGenerator())
    ..registerSingleton<AppDatabase>(infra.database, dispose: (db) => db.close())
    ..registerSingleton<OnDeviceAiRuntime>(infra.aiRuntime)
    ..registerSingleton<http.Client>(infra.httpClient, dispose: (c) => c.close());
}

void _registerRepositories(Infrastructure infra) {
  final memories = SqliteMemoryRepository(sl());
  sl
    // One instance serves both interfaces (Interface Segregation).
    ..registerSingleton<MemoryRepository>(memories, dispose: (_) => memories.disposeChanges())
    ..registerSingleton<MemoryMetadataStore>(memories)
    ..registerLazySingleton<CollectionRepository>(() => SqliteCollectionRepository(sl()))
    ..registerLazySingleton<TaskRepository>(() => SqliteTaskRepository(sl()))
    ..registerLazySingleton<ConversationRepository>(() => SqliteConversationRepository(sl()))
    ..registerLazySingleton<SearchHistoryRepository>(() => SqliteSearchHistoryRepository(sl()))
    ..registerLazySingleton<PreferencesRepository>(
      () => SharedPrefsPreferencesRepository(infra.preferences),
    )
    ..registerLazySingleton<ModelRepository>(() => OnDeviceModelRepository(sl(), sl()))
    ..registerSingleton<DataExportRepository>(infra.exporter);
}

void _registerServices() {
  bool languageModelInstalled() => sl<OnDeviceAiRuntime>().isInstalled(AiModelKind.languageModel);

  sl
    ..registerLazySingleton<TextEmbedder>(() => EmbeddingGemmaTextEmbedder(sl(), sl()))
    ..registerLazySingleton<LinkReader>(() => HttpLinkReader(sl(), sl()))
    ..registerLazySingleton<MemoryAnalyzer>(
      () => FallbackMemoryAnalyzer(
        primary: GemmaMemoryAnalyzer(sl(), const RuleBasedMemoryAnalyzer()),
        fallback: const RuleBasedMemoryAnalyzer(),
        isPrimaryAvailable: languageModelInstalled,
        logger: sl(),
      ),
    )
    ..registerLazySingleton<AnswerGenerator>(() => GemmaAnswerGenerator(sl()))
    ..registerLazySingleton<RecapWriter>(
      () => FallbackRecapWriter(
        primary: GemmaRecapWriter(sl()),
        fallback: const RuleBasedRecapWriter(),
        isPrimaryAvailable: languageModelInstalled,
        logger: sl(),
      ),
    )
    ..registerSingleton<SimilarityScorer>(const DefaultSimilarityScorer())
    ..registerSingleton<Map<SearchMode, RelevanceScorer>>(const {
      SearchMode.keyword: KeywordRelevanceScorer(),
      SearchMode.semantic: HybridRelevanceScorer(),
    });
}

void _registerUseCases() {
  sl
    // Search & indexing
    ..registerLazySingleton(
      () => SearchMemories(memories: sl(), embedder: sl(), scorers: sl(), logger: sl()),
    )
    ..registerLazySingleton(() => FindSimilarMemories(memories: sl(), scorer: sl()))
    ..registerLazySingleton(() => GetRecentSearches(sl(), sl()))
    ..registerLazySingleton(() => RecordSearch(sl(), sl(), sl()))
    ..registerLazySingleton(() => ClearSearchHistory(sl(), sl()))
    ..registerLazySingleton(() => IndexMemory(sl(), sl(), sl()))
    ..registerLazySingleton(
      () => IndexPendingMemories(embedder: sl(), metadata: sl(), indexMemory: sl(), logger: sl()),
    )
    // Capture
    ..registerLazySingleton(
      () => AnalyzeCapture(
        linkReader: sl(),
        analyzer: sl(),
        preferences: sl(),
        findSimilar: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton(
      () => SaveCapture(
        memories: sl(),
        tasks: sl(),
        indexMemory: sl(),
        ids: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    // Memories
    ..registerLazySingleton(
      () => ObserveDataChanges([
        sl<MemoryRepository>(),
        sl<CollectionRepository>(),
        sl<TaskRepository>(),
      ]),
    )
    ..registerLazySingleton(() => GetMemories(sl(), sl()))
    ..registerLazySingleton(() => GetCategories(sl(), sl()))
    ..registerLazySingleton(
      () => GetMemoryDetails(
        memories: sl(),
        metadata: sl(),
        tasks: sl(),
        collections: sl(),
        findSimilar: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton(() => ToggleFavorite(sl(), sl(), sl()))
    ..registerLazySingleton(() => ToggleArchived(sl(), sl(), sl()))
    ..registerLazySingleton(() => MoveMemoryToCollection(sl(), sl(), sl()))
    ..registerLazySingleton(() => EditMemory(sl(), sl(), sl(), sl()))
    ..registerLazySingleton(() => DeleteMemory(sl(), sl()))
    // Collections
    ..registerLazySingleton(() => GetCollections(sl(), sl()))
    ..registerLazySingleton(() => GetCollectionContents(sl(), sl(), sl()))
    ..registerLazySingleton(() => CreateCollection(sl(), sl(), sl(), sl()))
    ..registerLazySingleton(() => DeleteCollection(sl(), sl()))
    // Tasks
    ..registerLazySingleton(() => GetTaskBoard(sl(), sl(), sl(), sl()))
    ..registerLazySingleton(() => AddTask(sl(), sl(), sl(), sl()))
    ..registerLazySingleton(() => ToggleTaskDone(sl(), sl()))
    ..registerLazySingleton(() => SetTaskReminder(sl(), sl()))
    ..registerLazySingleton(() => DeleteTask(sl(), sl()))
    // Ask
    ..registerLazySingleton(() => RetrieveAnswerSources(sl()))
    ..registerLazySingleton(
      () => AskBrain(
        conversations: sl(),
        retrieveSources: sl(),
        generator: sl(),
        ids: sl(),
        clock: sl(),
      ),
    )
    ..registerLazySingleton(() => GetConversations(sl(), sl()))
    ..registerLazySingleton(() => OpenConversation(sl(), sl(), sl()))
    ..registerLazySingleton(() => DeleteConversation(sl(), sl()))
    ..registerLazySingleton(() => GetSuggestedQuestions(sl()))
    // Recall
    ..registerLazySingleton(() => RecallPolicy(sl()))
    ..registerLazySingleton(
      () => GetHomeOverview(
        memories: sl(),
        collections: sl(),
        tasks: sl(),
        recall: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton(() => GetDigest(tasks: sl(), recall: sl(), clock: sl(), logger: sl()))
    ..registerLazySingleton(() => WriteWeeklyRecap(sl(), sl()))
    // Models
    ..registerLazySingleton(() => GetAiOverview(sl(), sl()))
    ..registerLazySingleton(() => InstallAi(sl(), sl(), sl()))
    ..registerLazySingleton(() => CancelAiInstall(sl(), sl()))
    ..registerLazySingleton(() => UninstallAi(sl(), sl()))
    ..registerLazySingleton(() => ChangeComputeBackend(sl(), sl()))
    ..registerLazySingleton(() => UnloadModels(sl()))
    // Settings
    ..registerLazySingleton(() => GetAiSuggestionsEnabled(sl()))
    ..registerLazySingleton(() => SetAiSuggestionsEnabled(sl()))
    ..registerLazySingleton(
      () => ExportData(
        memories: sl(),
        collections: sl(),
        tasks: sl(),
        conversations: sl(),
        exporter: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton(
      () => WipeAllData([
        // Dependants first: messages/tasks reference memories and collections.
        sl<ConversationRepository>(),
        sl<TaskRepository>(),
        sl<MemoryRepository>(),
        sl<CollectionRepository>(),
        sl<SearchHistoryRepository>(),
      ], sl()),
    );
}

void _registerPresentation() {
  Stream<void> changes() => sl<ObserveDataChanges>()(noParams);

  sl
    ..registerFactory(
      () => ModelBloc(
        getOverview: sl(),
        installAi: sl(),
        cancelInstall: sl(),
        uninstallAi: sl(),
        changeBackend: sl(),
        unloadModels: sl(),
      ),
    )
    ..registerFactory(() => HomeCubit(getOverview: sl(), changes: changes()))
    ..registerFactory(
      () => LibraryCubit(
        getMemories: sl(),
        getCollections: sl(),
        getCategories: sl(),
        createCollection: sl(),
        changes: changes(),
      ),
    )
    ..registerFactory(
      () => CaptureBloc(analyzeCapture: sl(), saveCapture: sl(), getCollections: sl()),
    )
    ..registerFactory(
      () => AskBloc(
        askBrain: sl(),
        getConversations: sl(),
        openConversation: sl(),
        deleteConversation: sl(),
        getSuggestions: sl(),
        getCollections: sl(),
      ),
    )
    ..registerFactory(
      () => SearchBloc(
        searchMemories: sl(),
        getRecentSearches: sl(),
        recordSearch: sl(),
        clearHistory: sl(),
        getCategories: sl(),
        changes: changes(),
      ),
    )
    ..registerFactoryParam<MemoryDetailCubit, String, void>(
      (memoryId, _) => MemoryDetailCubit(
        memoryId: memoryId,
        changes: changes(),
        actions: MemoryDetailActions(
          getDetails: sl(),
          toggleFavorite: sl(),
          toggleArchived: sl(),
          moveToCollection: sl(),
          editMemory: sl(),
          deleteMemory: sl(),
          addTask: sl(),
          toggleTask: sl(),
        ),
      ),
    )
    ..registerFactoryParam<CollectionCubit, String, void>(
      (collectionId, _) => CollectionCubit(
        collectionId: collectionId,
        getContents: sl(),
        searchMemories: sl(),
        deleteCollection: sl(),
        changes: changes(),
      ),
    )
    ..registerFactory(() => DigestCubit(getDigest: sl(), writeRecap: sl(), changes: changes()))
    ..registerFactory(
      () => TasksCubit(
        changes: changes(),
        actions: TaskActions(
          getBoard: sl(),
          addTask: sl(),
          toggleTask: sl(),
          setReminder: sl(),
          deleteTask: sl(),
        ),
      ),
    )
    ..registerFactory(
      () => SettingsCubit(
        getAiSuggestions: sl(),
        setAiSuggestions: sl(),
        exportData: sl(),
        wipeAllData: sl(),
      ),
    );
}
