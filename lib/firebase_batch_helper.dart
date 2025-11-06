import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Helper for efficient Firebase batch operations
///
/// PERFORMANCE: Batch multiple Firestore operations into single requests
/// - Reduces network round trips
/// - Lower Firebase billing costs
/// - Atomic operations (all succeed or all fail)
/// - Up to 500 operations per batch
class FirebaseBatchHelper {
  final FirebaseFirestore _firestore;
  static const int _maxBatchSize = 500; // Firestore limit

  FirebaseBatchHelper({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Execute a batch write operation
  ///
  /// PERFORMANCE: Single network request for multiple writes
  Future<void> executeBatch(
    List<BatchOperation> operations, {
    String? operationName,
  }) async {
    if (operations.isEmpty) return;

    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;

    try {
      // Split into batches of 500 (Firestore limit)
      final batches = _splitIntoBatches(operations);

      if (kDebugMode) {
        debugPrint(
          '📦 FirebaseBatch: Executing ${operations.length} operations in ${batches.length} batch(es)',
        );
        if (operationName != null) {
          debugPrint('   Operation: $operationName');
        }
      }

      // Execute all batches
      for (var i = 0; i < batches.length; i++) {
        final batch = _firestore.batch();
        final batchOps = batches[i];

        for (final op in batchOps) {
          op.apply(batch);
        }

        await batch.commit();

        if (kDebugMode) {
          debugPrint('   ✅ Batch ${i + 1}/${batches.length} committed (${batchOps.length} ops)');
        }
      }

      if (kDebugMode) {
        debugPrint(
          '✅ FirebaseBatch: Completed in ${stopwatch!.elapsedMilliseconds}ms',
        );
      }
    } catch (e, st) {
      debugPrint('❌ FirebaseBatch: Error executing batch: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Batch read multiple documents efficiently
  ///
  /// PERFORMANCE: Parallel reads instead of sequential
  Future<Map<String, DocumentSnapshot>> batchRead(
    List<DocumentReference> refs, {
    String? operationName,
  }) async {
    if (refs.isEmpty) return {};

    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;

    try {
      if (kDebugMode) {
        debugPrint('📖 FirebaseBatch: Reading ${refs.length} documents in parallel');
        if (operationName != null) {
          debugPrint('   Operation: $operationName');
        }
      }

      // Execute all reads in parallel
      final futures = refs.map((ref) => ref.get()).toList();
      final snapshots = await Future.wait(futures);

      final result = <String, DocumentSnapshot>{};
      for (var i = 0; i < refs.length; i++) {
        result[refs[i].path] = snapshots[i];
      }

      if (kDebugMode) {
        debugPrint(
          '✅ FirebaseBatch: Read completed in ${stopwatch!.elapsedMilliseconds}ms',
        );
      }

      return result;
    } catch (e, st) {
      debugPrint('❌ FirebaseBatch: Error in batch read: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Update multiple documents with same data
  ///
  /// PERFORMANCE: Single batch for multiple updates
  Future<void> batchUpdate(
    List<DocumentReference> refs,
    Map<String, dynamic> data, {
    String? operationName,
  }) async {
    final operations = refs
        .map((ref) => BatchOperation.update(ref, data))
        .toList();

    await executeBatch(operations, operationName: operationName);
  }

  /// Delete multiple documents
  ///
  /// PERFORMANCE: Single batch for multiple deletes
  Future<void> batchDelete(
    List<DocumentReference> refs, {
    String? operationName,
  }) async {
    final operations = refs
        .map((ref) => BatchOperation.delete(ref))
        .toList();

    await executeBatch(operations, operationName: operationName);
  }

  List<List<BatchOperation>> _splitIntoBatches(List<BatchOperation> operations) {
    final batches = <List<BatchOperation>>[];
    for (var i = 0; i < operations.length; i += _maxBatchSize) {
      final end = (i + _maxBatchSize).clamp(0, operations.length);
      batches.add(operations.sublist(i, end));
    }
    return batches;
  }
}

/// Represents a single batch operation
abstract class BatchOperation {
  void apply(WriteBatch batch);

  /// Create a set operation
  factory BatchOperation.set(
    DocumentReference ref,
    Map<String, dynamic> data, {
    bool merge = false,
  }) = _SetOperation;

  /// Create an update operation
  factory BatchOperation.update(
    DocumentReference ref,
    Map<String, dynamic> data,
  ) = _UpdateOperation;

  /// Create a delete operation
  factory BatchOperation.delete(DocumentReference ref) = _DeleteOperation;
}

class _SetOperation implements BatchOperation {
  final DocumentReference ref;
  final Map<String, dynamic> data;
  final bool merge;

  _SetOperation(this.ref, this.data, {this.merge = false});

  @override
  void apply(WriteBatch batch) {
    if (merge) {
      batch.set(ref, data, SetOptions(merge: true));
    } else {
      batch.set(ref, data);
    }
  }
}

class _UpdateOperation implements BatchOperation {
  final DocumentReference ref;
  final Map<String, dynamic> data;

  _UpdateOperation(this.ref, this.data);

  @override
  void apply(WriteBatch batch) {
    batch.update(ref, data);
  }
}

class _DeleteOperation implements BatchOperation {
  final DocumentReference ref;

  _DeleteOperation(this.ref);

  @override
  void apply(WriteBatch batch) {
    batch.delete(ref);
  }
}

/// Extension for convenient batch operations
extension DocumentReferenceBatchExtension on List<DocumentReference> {
  /// Batch read all document references
  Future<Map<String, DocumentSnapshot>> batchRead() {
    return FirebaseBatchHelper().batchRead(this);
  }

  /// Batch update all documents with same data
  Future<void> batchUpdate(Map<String, dynamic> data) {
    return FirebaseBatchHelper().batchUpdate(this, data);
  }

  /// Batch delete all documents
  Future<void> batchDelete() {
    return FirebaseBatchHelper().batchDelete(this);
  }
}

/// Query helper for efficient batch queries
class QueryBatchHelper {
  /// Get all documents from a query efficiently
  ///
  /// PERFORMANCE: Single query instead of multiple doc reads
  static Future<List<DocumentSnapshot>> getAllDocuments(
    Query query, {
    int? limit,
  }) async {
    Query finalQuery = query;
    if (limit != null) {
      finalQuery = query.limit(limit);
    }

    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;

    try {
      final snapshot = await finalQuery.get();

      if (kDebugMode) {
        debugPrint(
          '📊 QueryBatch: Retrieved ${snapshot.docs.length} documents in ${stopwatch!.elapsedMilliseconds}ms',
        );
      }

      return snapshot.docs;
    } catch (e) {
      debugPrint('❌ QueryBatch: Error: $e');
      rethrow;
    }
  }

  /// Get documents in pages for large collections
  ///
  /// PERFORMANCE: Pagination reduces memory usage and initial load time
  static Stream<List<DocumentSnapshot>> getPaginatedDocuments(
    Query query,
    int pageSize,
  ) async* {
    DocumentSnapshot? lastDoc;
    var hasMore = true;
    var pageCount = 0;

    while (hasMore) {
      Query pageQuery = query.limit(pageSize);

      if (lastDoc != null) {
        pageQuery = pageQuery.startAfterDocument(lastDoc);
      }

      final snapshot = await pageQuery.get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        hasMore = false;
      } else {
        pageCount++;
        if (kDebugMode) {
          debugPrint('📄 QueryBatch: Page $pageCount (${docs.length} docs)');
        }

        yield docs;
        lastDoc = docs.last;

        if (docs.length < pageSize) {
          hasMore = false;
        }
      }
    }
  }
}

/// Example usage patterns
class BatchOperationExamples {
  /// Example: Update multiple user stats in one batch
  static Future<void> updateMultipleUserStats(
    FirebaseFirestore firestore,
    Map<String, Map<String, dynamic>> userUpdates,
  ) async {
    final operations = userUpdates.entries.map((entry) {
      final ref = firestore.collection('users').doc(entry.key);
      return BatchOperation.update(ref, entry.value);
    }).toList();

    await FirebaseBatchHelper(firestore: firestore).executeBatch(
      operations,
      operationName: 'Update multiple user stats',
    );
  }

  /// Example: Read multiple user documents efficiently
  static Future<Map<String, DocumentSnapshot>> readMultipleUsers(
    FirebaseFirestore firestore,
    List<String> userIds,
  ) async {
    final refs = userIds
        .map((id) => firestore.collection('users').doc(id))
        .toList();

    return FirebaseBatchHelper(firestore: firestore).batchRead(
      refs,
      operationName: 'Read multiple users',
    );
  }

  /// Example: Delete old notifications in batch
  static Future<void> deleteOldNotifications(
    FirebaseFirestore firestore,
    String userId,
    DateTime olderThan,
  ) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('createdAt', isLessThan: Timestamp.fromDate(olderThan))
        .get();

    if (snapshot.docs.isEmpty) return;

    final operations = snapshot.docs
        .map((doc) => BatchOperation.delete(doc.reference))
        .toList();

    await FirebaseBatchHelper(firestore: firestore).executeBatch(
      operations,
      operationName: 'Delete old notifications',
    );
  }
}
