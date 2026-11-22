import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class AssessmentCareerMatch {
  const AssessmentCareerMatch({
    required this.title,
    required this.matchPercent,
  });

  final String title;
  final int matchPercent;

  Map<String, Object> toMap() => {'title': title, 'matchPercent': matchPercent};

  factory AssessmentCareerMatch.fromMap(Map<String, Object?> map) {
    final title = map['title'];
    final percent = map['matchPercent'];
    if (title is! String || percent is! num) {
      throw const FormatException('Invalid top-career match record.');
    }
    return AssessmentCareerMatch(title: title, matchPercent: percent.round());
  }
}

class AssessmentRecord {
  AssessmentRecord({
    required this.id,
    required this.createdAt,
    required this.educationLevel,
    required this.group,
    required this.percentage,
    required Map<String, int> riasecScores,
    required Map<String, int> skills,
    required List<AssessmentCareerMatch> top5,
    required this.topCareer,
    required this.engine,
  }) : riasecScores = Map.unmodifiable(riasecScores),
       skills = Map.unmodifiable(skills),
       top5 = List.unmodifiable(top5);

  final String id;
  final DateTime createdAt;
  final String educationLevel;
  final String group;
  final double percentage;
  final Map<String, int> riasecScores;
  final Map<String, int> skills;
  final List<AssessmentCareerMatch> top5;
  final String topCareer;
  final String engine;

  Map<String, Object?> toMap() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'educationLevel': educationLevel,
    'group': group,
    'percentage': percentage,
    'riasecScores': riasecScores,
    'skills': skills,
    'top5': top5.map((match) => match.toMap()).toList(),
    'topCareer': topCareer,
    'engine': engine,
  };

  factory AssessmentRecord.fromMap(
    Map<String, Object?> map, {
    String? documentId,
  }) {
    final id = documentId ?? map['id'];
    final createdAtValue = map['createdAt'];
    final educationLevel = map['educationLevel'];
    final group = map['group'];
    final percentage = map['percentage'];
    final topCareer = map['topCareer'];
    final engine = map['engine'];
    if (id is! String ||
        educationLevel is! String ||
        group is! String ||
        percentage is! num ||
        topCareer is! String ||
        engine is! String ||
        (engine != 'tflite' &&
            engine != 'fallback' &&
            engine != 'stream_rules')) {
      throw const FormatException('Invalid assessment record.');
    }

    final DateTime createdAt;
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    } else if (createdAtValue is String) {
      final parsedDate = DateTime.tryParse(createdAtValue);
      if (parsedDate == null) {
        throw const FormatException('Invalid assessment timestamp.');
      }
      createdAt = parsedDate;
    } else {
      throw const FormatException('Invalid assessment timestamp.');
    }

    return AssessmentRecord(
      id: id,
      createdAt: createdAt,
      educationLevel: educationLevel,
      group: group,
      percentage: percentage.toDouble(),
      riasecScores: _integerMap(map['riasecScores'], 'riasecScores'),
      skills: _integerMap(map['skills'], 'skills'),
      top5: _topCareerMatches(map['top5']),
      topCareer: topCareer,
      engine: engine,
    );
  }

  static Map<String, int> _integerMap(Object? value, String field) {
    if (value is! Map ||
        value.keys.any((key) => key is! String) ||
        value.values.any((item) => item is! int)) {
      throw FormatException('Invalid assessment field "$field".');
    }
    return Map.unmodifiable(value.cast<String, int>());
  }

  static List<AssessmentCareerMatch> _topCareerMatches(Object? value) {
    if (value is! List) {
      throw const FormatException('Invalid assessment field "top5".');
    }
    return List.unmodifiable(
      value.map((item) {
        if (item is! Map || item.keys.any((key) => key is! String)) {
          throw const FormatException('Invalid top-career match record.');
        }
        return AssessmentCareerMatch.fromMap(item.cast<String, Object?>());
      }),
    );
  }
}

class AssessmentHistorySnapshot {
  AssessmentHistorySnapshot({
    required List<AssessmentRecord> records,
    required this.isSignedIn,
    required this.hasRemoteConnection,
    required Set<String> syncedIds,
  }) : records = List.unmodifiable(records),
       syncedIds = Set.unmodifiable(syncedIds);

  final List<AssessmentRecord> records;
  final bool isSignedIn;
  final bool hasRemoteConnection;
  final Set<String> syncedIds;

  bool get isSynced =>
      isSignedIn &&
      hasRemoteConnection &&
      records.every((record) => syncedIds.contains(record.id));

  AssessmentHistorySnapshot withRecords(List<AssessmentRecord> nextRecords) {
    return AssessmentHistorySnapshot(
      records: nextRecords,
      isSignedIn: isSignedIn,
      hasRemoteConnection: hasRemoteConnection,
      syncedIds: syncedIds,
    );
  }
}

class HistoryRepository {
  HistoryRepository({
    required this.authService,
    this.firestore,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const String _guestCacheKey = 'assessment_history_guest';
  static const String _cachePrefix = 'assessment_history_';
  static const String _deletedPrefix = 'assessment_history_deleted_';
  static const String _idAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final Random _random = Random.secure();

  FirebaseFirestore get _database => firestore ?? FirebaseFirestore.instance;

  String createId() {
    final userId = authService?.currentUser?.uid;
    if (userId != null) {
      return _assessments(userId).doc().id;
    }
    return List.generate(
      20,
      (_) => _idAlphabet[_random.nextInt(_idAlphabet.length)],
    ).join();
  }

  Future<bool> save(AssessmentRecord record) async {
    final userId = authService?.currentUser?.uid;
    final key = _cacheKey(userId);
    final cached = await _readRecords(key);
    cached.removeWhere((item) => item.id == record.id);
    cached.add(record);
    await _writeRecords(key, _sortNewestFirst(cached));

    if (userId == null) return false;
    try {
      await _assessments(userId).doc(record.id).set(_firestoreData(record));
      return true;
    } catch (error) {
      debugPrint('Assessment saved locally; Firestore sync failed: $error');
      return false;
    }
  }

  Future<List<AssessmentRecord>> load() async =>
      (await loadWithStatus()).records;

  Future<AssessmentHistorySnapshot> loadWithStatus() async {
    final userId = authService?.currentUser?.uid;
    if (userId == null) {
      return AssessmentHistorySnapshot(
        records: _sortNewestFirst(await _readRecords(_guestCacheKey)),
        isSignedIn: false,
        hasRemoteConnection: false,
        syncedIds: const {},
      );
    }

    await syncPending();
    try {
      final snapshot = await _assessments(userId)
          .orderBy('createdAt', descending: true)
          .get();
      final records = snapshot.docs
          .map(
            (document) => AssessmentRecord.fromMap(
              document.data(),
              documentId: document.id,
            ),
          )
          .toList();
      final deletedIds = await _readDeletedIds(userId);
      final localRecords = await _readRecords(_cacheKey(userId));
      final merged = <String, AssessmentRecord>{
        for (final record in localRecords)
          if (!deletedIds.contains(record.id)) record.id: record,
        for (final record in records)
          if (!deletedIds.contains(record.id)) record.id: record,
      };
      final sorted = _sortNewestFirst(merged.values);
      await _writeRecords(_cacheKey(userId), sorted);
      return AssessmentHistorySnapshot(
        records: sorted,
        isSignedIn: true,
        hasRemoteConnection: !snapshot.metadata.isFromCache,
        syncedIds: snapshot.docs
            .where((document) => !document.metadata.hasPendingWrites)
            .map((document) => document.id)
            .toSet(),
      );
    } catch (error) {
      debugPrint('Could not load assessment history from Firestore: $error');
      final deletedIds = await _readDeletedIds(userId);
      final local = await _readRecords(_cacheKey(userId));
      return AssessmentHistorySnapshot(
        records: _sortNewestFirst(
          local.where((record) => !deletedIds.contains(record.id)),
        ),
        isSignedIn: true,
        hasRemoteConnection: false,
        syncedIds: const {},
      );
    }
  }

  Future<void> syncPending() async {
    final userId = authService?.currentUser?.uid;
    if (userId == null) return;

    final userCacheKey = _cacheKey(userId);
    final userRecords = await _readRecords(userCacheKey);
    final guestRecords = await _readRecords(_guestCacheKey);
    final deletedIds = await _readDeletedIds(userId);
    final merged = <String, AssessmentRecord>{
      for (final record in userRecords)
        if (!deletedIds.contains(record.id)) record.id: record,
      for (final record in guestRecords)
        if (!deletedIds.contains(record.id)) record.id: record,
    };
    await _writeRecords(userCacheKey, _sortNewestFirst(merged.values));
    await _writeRecords(_guestCacheKey, const []);

    for (final id in deletedIds.toList()) {
      try {
        await _assessments(userId).doc(id).delete();
        deletedIds.remove(id);
        await _writeDeletedIds(userId, deletedIds);
      } catch (error) {
        debugPrint('Could not sync assessment deletion "$id": $error');
      }
    }

    for (final record in merged.values) {
      try {
        final document = _assessments(userId).doc(record.id);
        final snapshot = await document.get();
        if (!snapshot.exists) {
          await document.set(_firestoreData(record));
        }
      } catch (error) {
        debugPrint(
          'Could not sync assessment "${record.id}" to Firestore: $error',
        );
      }
    }
  }

  Future<void> delete(String id) async {
    final userId = authService?.currentUser?.uid;
    await _removeCachedRecord(_cacheKey(userId), id);
    if (userId == null) {
      return;
    }

    final deletedIds = await _readDeletedIds(userId);
    deletedIds.add(id);
    await _writeDeletedIds(userId, deletedIds);
    try {
      await _assessments(userId).doc(id).delete();
      deletedIds.remove(id);
      await _writeDeletedIds(userId, deletedIds);
    } catch (error) {
      debugPrint('Assessment deletion queued for sync: $error');
    }
  }

  Future<void> clearAll() async {
    final userId = authService?.currentUser?.uid;
    final cacheKey = _cacheKey(userId);
    final local = await _readRecords(cacheKey);

    if (userId == null) {
      await _writeRecords(_guestCacheKey, const []);
      return;
    }

    final deletedIds = await _readDeletedIds(userId)
      ..addAll(local.map((record) => record.id));
    try {
      final snapshot = await _assessments(userId).get();
      deletedIds.addAll(snapshot.docs.map((document) => document.id));
    } catch (error) {
      debugPrint('Firestore clear queued for sync: $error');
    }
    await _writeRecords(cacheKey, const []);
    await _writeDeletedIds(userId, deletedIds);
    for (final id in deletedIds.toList()) {
      try {
        await _assessments(userId).doc(id).delete();
        deletedIds.remove(id);
        await _writeDeletedIds(userId, deletedIds);
      } catch (error) {
        debugPrint('Could not clear assessment "$id": $error');
      }
    }
    final preferences = await _preferencesProvider();
    await preferences.remove(_guestCacheKey);
  }

  CollectionReference<Map<String, dynamic>> _assessments(String userId) =>
      _database.collection('users').doc(userId).collection('assessments');

  static Map<String, Object?> _firestoreData(AssessmentRecord record) {
    final data = record.toMap()..remove('id');
    data['createdAt'] = Timestamp.fromDate(record.createdAt.toUtc());
    return data;
  }

  static String _cacheKey(String? userId) =>
      userId == null ? _guestCacheKey : '$_cachePrefix$userId';

  static String _deletedKey(String userId) => '$_deletedPrefix$userId';

  Future<List<AssessmentRecord>> _readRecords(String key) async {
    final preferences = await _preferencesProvider();
    final contents = preferences.getString(key);
    if (contents == null) return [];
    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw FormatException('Cached assessment history "$key" is invalid.');
    }
    return decoded.map((item) {
      if (item is! Map || item.keys.any((field) => field is! String)) {
        throw FormatException('Cached assessment history "$key" is invalid.');
      }
      return AssessmentRecord.fromMap(item.cast<String, Object?>());
    }).toList();
  }

  Future<void> _writeRecords(String key, List<AssessmentRecord> records) async {
    final preferences = await _preferencesProvider();
    final saved = await preferences.setString(
      key,
      jsonEncode(records.map((record) => record.toMap()).toList()),
    );
    if (!saved) throw StateError('Could not save local assessment history.');
  }

  Future<Set<String>> _readDeletedIds(String userId) async {
    final preferences = await _preferencesProvider();
    final contents = preferences.getString(_deletedKey(userId));
    if (contents == null) return {};
    final decoded = jsonDecode(contents);
    if (decoded is! List || decoded.any((id) => id is! String)) {
      throw FormatException(
        'Cached assessment deletions for "$userId" invalid.',
      );
    }
    return decoded.cast<String>().toSet();
  }

  Future<void> _writeDeletedIds(String userId, Set<String> ids) async {
    final preferences = await _preferencesProvider();
    if (ids.isEmpty) {
      await preferences.remove(_deletedKey(userId));
      return;
    }
    final saved = await preferences.setString(
      _deletedKey(userId),
      jsonEncode(ids.toList()),
    );
    if (!saved) throw StateError('Could not save pending deletions.');
  }

  Future<void> _removeCachedRecord(String key, String id) async {
    final cached = await _readRecords(key);
    cached.removeWhere((record) => record.id == id);
    await _writeRecords(key, cached);
  }

  static List<AssessmentRecord> _sortNewestFirst(
    Iterable<AssessmentRecord> records,
  ) {
    final sorted = records.toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return List.unmodifiable(sorted);
  }
}
