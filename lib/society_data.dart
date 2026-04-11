// lib/screens/society_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SocietyData {
  static final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════
  // MAINTENANCE FEE — sirf yahan change karo
  // ═══════════════════════════════════════════════════
  static const double monthlyFee = 700.0;
  static const int    maxHistory = 24; // 2 years history

  // ═══════════════════════════════════════════════════
  // 5 ADMIN — real names as IDs
  // ═══════════════════════════════════════════════════
  static Map<String, String> adminPasswords = {
    'NOVROZ':  'novroz123',
    'MEHMOOD': 'mehmood123',
    'IKHLAQ':  'ikhlaq123',
    'FAISAL':  'faisal123',
    'UMAR':    'umar123',
  };

  static const Map<String, String> adminNames = {
    'NOVROZ':  'Novroz Ali',
    'MEHMOOD': 'Mehmood Zaman',
    'IKHLAQ':  'Ikhlaq Tajik',
    'FAISAL':  'Faisal',
    'UMAR':    'Umar',
  };

  static String getAdminDisplayName(String id) =>
      adminNames[id.toUpperCase()] ?? id;

  static bool isAdminLogin(String id, String pass) =>
      adminPasswords[id.toUpperCase()] == pass;

  static bool isAdminId(String id) =>
      adminPasswords.containsKey(id.toUpperCase());

  static Future<void> changeAdminPassword(String adminId, String newPass) async {
    adminPasswords[adminId.toUpperCase()] = newPass;
    await _db.collection('admin_passwords').doc(adminId.toUpperCase()).set({
      'adminId': adminId.toUpperCase(),
      'pass': newPass,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _loadAdminPasswords() async {
    try {
      final snap = await _db.collection('admin_passwords').get();
      for (final doc in snap.docs) {
        final id   = doc.data()['adminId'] as String? ?? doc.id;
        final pass = doc.data()['pass']    as String? ?? '';
        if (pass.isNotEmpty) adminPasswords[id] = pass;
      }
    } catch (e) { debugPrint('loadAdminPasswords: $e'); }
  }

  // ═══════════════════════════════════════════════════
  // ACTIVITY LOG — real-time stream + clear on refresh
  // ═══════════════════════════════════════════════════
  static List<Map<String, dynamic>> activityLog = [];

  static Stream<List<Map<String, dynamic>>> activityLogStream() {
    return _db
        .collection('activity_log')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return {
                'id':        doc.id,
                'adminId':   d['adminId']   ?? '',
                'adminName': d['adminName'] ?? d['adminId'] ?? '',
                'action':    d['action']    ?? '',
                'house':     d['house']     ?? '',
                'detail':    d['detail']    ?? '',
                'timestamp': d['timestamp'],
              };
            }).toList());
  }

  /// Refresh button — Firebase se sab activity delete karo
  static Future<void> clearActivityLog() async {
    try {
      final snap = await _db.collection('activity_log').get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      activityLog = [];
    } catch (e) { debugPrint('clearActivityLog: $e'); }
  }

  static Future<void> logActivity({
    required String adminId,
    required String action,
    required String house,
    String detail = '',
  }) async {
    await _db.collection('activity_log').add({
      'adminId':   adminId,
      'adminName': getAdminDisplayName(adminId),
      'action':    action,
      'house':     house,
      'detail':    detail,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _loadActivityLog() async {
    try {
      final snap = await _db
          .collection('activity_log')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      activityLog = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id':        doc.id,
          'adminId':   d['adminId']   ?? '',
          'adminName': d['adminName'] ?? d['adminId'] ?? '',
          'action':    d['action']    ?? '',
          'house':     d['house']     ?? '',
          'detail':    d['detail']    ?? '',
          'timestamp': d['timestamp'],
        };
      }).toList();
    } catch (e) { activityLog = []; }
  }

  // ═══════════════════════════════════════════════════
  // DATA
  // ═══════════════════════════════════════════════════
  static List<Map<String, dynamic>> allPayments = [];
  static List<Map<String, dynamic>>  userRecords  = [];
  static Map<String, List<Map<String, dynamic>>> houseHistory = {};

  static Future<void> initializeRecords() async {
    await _loadAdminPasswords();
    await _loadUsers();
    await _loadPayments();
    await _loadActivityLog();
    await loadMaintenanceTeam();
    if (userRecords.isEmpty) await _createDefaultUsers();
  }

  static Future<void> _createDefaultUsers() async {
    final batch = _db.batch();
    final col   = _db.collection('users');
    for (final house in allHouses) {
      batch.set(col.doc(house), {
        'house': house, 'mobile': 'Not Registered',
        'email': 'Not Registered', 'pass': '1234',
      });
      userRecords.add({'house': house, 'mobile': 'Not Registered',
          'email': 'Not Registered', 'pass': '1234'});
    }
    await batch.commit();
  }

  static Future<void> _loadUsers() async {
    try {
      final snap = await _db.collection('users').get();
      userRecords = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'house':      (d['house']  ?? doc.id).toString(),
          'mobile':     (d['mobile'] ?? 'Not Registered').toString(),
          'email':      (d['email']  ?? 'Not Registered').toString(),
          'pass':       (d['pass']   ?? '1234').toString(),
          // Keep old duesByYear for backward compatibility
          'duesByYear': d['duesByYear'] ?? {},
        };
      }).toList();
      userRecords.sort((a, b) => a['house']!.compareTo(b['house']!));
    } catch (e) { userRecords = []; }
  }

  static Future<void> _loadPayments() async {
    try {
      final snap = await _db.collection('payments').get();
      allPayments  = [];
      houseHistory = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        final payment = {
          'id':     doc.id,
          'house':  d['house']  ?? '',
          'month':  d['month']  ?? '',
          'year':   d['year']   ?? '',
          'amount': (d['amount'] as num?)?.toDouble() ?? 0.0,
          'date':   d['date']   ?? '',
          'img':    d['img']    ?? '',
          'period': d['period'] ?? '',
        };
        allPayments.add(payment);
        final house  = payment['house'] as String;
        final period = payment['period'] as String;
        if (period.isNotEmpty) {
          houseHistory.putIfAbsent(house, () => []);
          final exists = houseHistory[house]!.any((h) => h['period'] == period);
          if (!exists) {
            houseHistory[house]!.add(<String, dynamic>{
              'period': period,
              'date':   payment['date'] as String,
              'amount': (payment['amount'] as double).toStringAsFixed(0),
              'img':    payment['img']  as String,
            });
          }
        }
      }
      for (final house in houseHistory.keys) {
        houseHistory[house]!.sort((a, b) => b['date']!.compareTo(a['date']!));
      }
    } catch (e) { allPayments = []; houseHistory = {}; }
  }

  // ═══════════════════════════════════════════════════
  // SAVE USER
  // ═══════════════════════════════════════════════════
  static Future<void> saveUsers() async {
    for (final r in userRecords) {
      await _db.collection('users').doc(r['house']!).set({
        'house':  r['house'], 'mobile': r['mobile'] ?? 'Not Registered',
        'email':  r['email']  ?? 'Not Registered', 'pass': r['pass'] ?? '1234',
      });
    }
  }

  static Future<void> saveUser(String house) async {
    final r = userRecords.firstWhere(
        (u) => u['house'] == house, orElse: () => {});
    if (r.isEmpty) return;
    await _db.collection('users').doc(house).set({
      'house':  house, 'mobile': r['mobile'] ?? 'Not Registered',
      'email':  r['email']  ?? 'Not Registered', 'pass': r['pass'] ?? '1234',
    });
  }

  // ═══════════════════════════════════════════════════
  // DUPLICATE CHECK — same month same year 2 baar nahi
  // ═══════════════════════════════════════════════════
  static bool isMonthPaid(String house, String month, String year) {
    // Check new payments collection
    if (allPayments.any((p) =>
        p['house'] == house &&
        p['month'] == month &&
        p['year']  == year)) return true;

    // Check old duesByYear data in userRecords
    final userRec = userRecords.firstWhere(
        (r) => r['house']?.toString().toUpperCase() == house.toUpperCase(),
        orElse: () => {});
    final rawDues = userRec['duesByYear'];
    if (rawDues == null) return false;
    final duesByYear = Map<String, dynamic>.from(
        (rawDues as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)));
    final rawYear = duesByYear[year];
    if (rawYear == null) return false;
    final yearData = Map<String, dynamic>.from(
        (rawYear as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)));
    return yearData[month] == true;
  }

  /// Returns already-paid months list (for showing warning to admin)
  static List<String> getAlreadyPaidMonths(
      String house, List<String> months, String year) {
    return months.where((m) => isMonthPaid(house, m, year)).toList();
  }

  // ═══════════════════════════════════════════════════
  // ADD PAYMENT — duplicate months skip + 12 month limit
  // Returns list of already-paid months (empty = success)
  // ═══════════════════════════════════════════════════
  // Multi-year payment support
  // monthsWithYears: list of {'month': 'January', 'year': '2025'}
  static Future<List<String>> addPaymentMultiYear({
    required String house,
    required List<Map<String, dynamic>> monthsWithYears,
    required double amount,
    required String date,
    required String imgPath,
    required String adminId,
  }) async {
    // Already paid check
    final alreadyPaid = <String>[];
    final newEntries  = <Map<String, dynamic>>[];

    for (final entry in monthsWithYears) {
      final m = entry['month']!;
      final y = entry['year']!;
      if (isMonthPaid(house, m, y)) {
        alreadyPaid.add('$m $y');
      } else {
        newEntries.add(entry);
      }
    }

    if (newEntries.isEmpty) return alreadyPaid;

    // Period string — e.g. "Jan 2025, Dec 2025, Jan 2026"
    final periodParts = newEntries.map((e) {
      final shortMonth = e['month']!.substring(0, 3);
      return '$shortMonth ${e['year']}';
    }).join(', ');

    final split = amount / newEntries.length;

    houseHistory.putIfAbsent(house, () => []);
    houseHistory[house]!.insert(0, {
      'period': periodParts, 'date': date,
      'amount': amount.toStringAsFixed(0), 'img': imgPath,
    } as Map<String, dynamic>);

    if (houseHistory[house]!.length > maxHistory) {
      final oldest = houseHistory[house]!.removeLast();
      _deleteByPeriod(house, oldest['period'] ?? ''); // non-blocking
    }

    // Batch write - all payments in one Firebase round trip
    final batch = _db.batch();
    final docRefs = <DocumentReference>[];
    final payments = <Map<String, dynamic>>[];

    for (final entry in newEntries) {
      final m = entry['month']!;
      final y = entry['year']!;
      final docRef = _db.collection('payments').doc();
      final payment = {
        'house': house, 'month': m, 'year': y,
        'amount': split, 'date': date, 'img': imgPath,
        'period': periodParts, 'addedBy': adminId,
        'addedByName': getAdminDisplayName(adminId),
      };
      batch.set(docRef, payment);
      docRefs.add(docRef);
      payments.add(payment);
    }

    await batch.commit();

    // ✅ CRITICAL: Wait 500ms to ensure Firebase writes propagate
    await Future.delayed(const Duration(milliseconds: 500));

    // Update memory after batch
    for (int i = 0; i < payments.length; i++) {
      allPayments.add({...payments[i], 'id': docRefs[i].id});
    }
    
    // ✅ CRITICAL: Refresh from Firebase to get fresh data
    await _loadPayments();

    // Log activity without blocking UI
    logActivity(
        adminId: adminId, action: 'Payment Add', house: house,
        detail: 'Rs.${amount.toStringAsFixed(0)} — $periodParts');

    return alreadyPaid;
  }

  // Legacy single-year addPayment (backward compatible)
  static Future<List<String>> addPayment({
    required String house,
    required List<String> months,
    required String year,
    required double amount,
    required String date,
    required String imgPath,
    required String adminId,
  }) async {
    final monthsWithYears = months.map((m) => {'month': m, 'year': year}).toList();
    final alreadyPaidFull = await addPaymentMultiYear(
      house: house, monthsWithYears: monthsWithYears,
      amount: amount, date: date, imgPath: imgPath, adminId: adminId,
    );
    // Return just month names for backward compat
    return alreadyPaidFull.map((s) => s.split(' ').first).toList();
  }

  static Future<void> _deleteByPeriod(String house, String period) async {
    if (period.isEmpty) return;
    try {
      final snap = await _db.collection('payments')
          .where('house',  isEqualTo: house)
          .where('period', isEqualTo: period)
          .get();
      for (final doc in snap.docs) await doc.reference.delete();
      allPayments.removeWhere(
          (p) => p['house'] == house && p['period'] == period);
    } catch (e) { debugPrint('_deleteByPeriod: $e'); }
  }

  // ═══════════════════════════════════════════════════
  // DELETE PAYMENT
  // ═══════════════════════════════════════════════════
  static Future<void> deletePayment({
    required String house,
    required int histIndex,
    required String adminId,
  }) async {
    final hist = houseHistory[house];
    if (hist == null || histIndex >= hist.length) return;
    final period = hist[histIndex]['period'] ?? '';
    final date   = hist[histIndex]['date']   ?? '';

    final snap = await _db.collection('payments')
        .where('house',  isEqualTo: house)
        .where('period', isEqualTo: period)
        .where('date',   isEqualTo: date)
        .get();
    for (final doc in snap.docs) await doc.reference.delete();

    hist.removeAt(histIndex);
    allPayments.removeWhere((p) =>
        p['house'] == house && p['period'] == period && p['date'] == date);

    await logActivity(
        adminId: adminId, action: 'Payment Delete',
        house: house, detail: period);
  }

  // ═══════════════════════════════════════════════════
  // UPDATE VOUCHER
  // ═══════════════════════════════════════════════════
  static Future<void> updateVoucher({
    required String house,
    required int histIndex,
    required String newImgPath,
    required String adminId,
  }) async {
    final hist = houseHistory[house];
    if (hist == null || histIndex >= hist.length) return;
    final period = hist[histIndex]['period'] ?? '';
    hist[histIndex]['img'] = newImgPath;

    final snap = await _db.collection('payments')
        .where('house',  isEqualTo: house)
        .where('period', isEqualTo: period)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'img': newImgPath});
    }
    await logActivity(
        adminId: adminId, action: 'Voucher Update',
        house: house, detail: period);
  }

  // ═══════════════════════════════════════════════════
  // EDIT PAYMENT
  // ═══════════════════════════════════════════════════
  static Future<void> savePaymentEdit(
      String house, int histIndex, String newDate, String newAmount,
      {String adminId = 'NOVROZ'}) async {
    try {
      final period = houseHistory[house]?[histIndex]['period'] ?? '';
      if (period.isEmpty) return;
      if (histIndex < (houseHistory[house]?.length ?? 0)) {
        houseHistory[house]![histIndex]['date']   = newDate;
        houseHistory[house]![histIndex]['amount'] = newAmount;
      }
      final snap = await _db.collection('payments')
          .where('house',  isEqualTo: house)
          .where('period', isEqualTo: period)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'date': newDate});
      }
      await logActivity(
          adminId: adminId, action: 'Payment Edit',
          house: house, detail: '$period → Date: $newDate');
    } catch (e) { debugPrint('savePaymentEdit: $e'); }
  }

  // ═══════════════════════════════════════════════════
  // DUES — current month INCLUDE karo
  // Feb 2026 chal raha hai + Feb pay nahi => Feb dues mein
  // Feb 2026 pay ho gaya => 0 dues (clear!)
  // ═══════════════════════════════════════════════════
  static const List<String> _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  // Find the last paid month+year for a house
  static Map<String, int>? getLastPaidMonthYear(String house) {
    if (allPayments.isEmpty) return null;
    final housePay = allPayments.where((p) => p['house'] == house).toList();
    if (housePay.isEmpty) return null;

    int? lastYear;
    int? lastMonth;
    for (final p in housePay) {
      final y = int.tryParse(p['year']?.toString() ?? '') ?? 0;
      final m = _months.indexOf(p['month']?.toString() ?? '') + 1;
      if (m <= 0) continue;
      if (lastYear == null || y > lastYear || (y == lastYear && m > lastMonth!)) {
        lastYear  = y;
        lastMonth = m;
      }
    }
    if (lastYear == null) return null;
    return {'year': lastYear, 'month': lastMonth!};
  }

  // Smart getDuesMonths: only show dues AFTER last paid month
  static List<String> getDuesMonths(String house, String year) {
    final paidSet = allPayments
        .where((p) => p['house'] == house && p['year'] == year)
        .map((p) => p['month'] as String)
        .toSet();
    final now = DateTime.now();
    final targetYear = int.tryParse(year) ?? now.year;
    final maxMonth = targetYear < now.year ? 12 : now.month;

    // Find last paid point across ALL years
    final lastPaid = getLastPaidMonthYear(house);

    return _months.asMap().entries.where((e) {
      final monthNum = e.key + 1;
      final monthName = e.value;
      if (monthNum > maxMonth) return false;
      if (paidSet.contains(monthName)) return false;

      // If house has payment history, only show dues AFTER last paid month
      if (lastPaid != null) {
        final lastY = lastPaid['year']!;
        final lastM = lastPaid['month']!;
        // This month is before or same as last paid — skip
        if (targetYear < lastY) return false;
        if (targetYear == lastY && monthNum <= lastM) return false;
      }
      return true;
    }).map((e) => e.value).toList();
  }

  static double getDuesAmount(String house, String year) =>
      getDuesMonths(house, year).length * monthlyFee;

  // Total paid (lifetime) — all years
  static double getTotalPaidAllTime(String house) {
    return allPayments
        .where((p) => p['house'] == house)
        .fold(0.0, (s, p) => s + (p['amount'] as double));
  }

  // Total paid months count — all years
  static int getTotalPaidMonthsCount(String house) {
    return allPayments
        .where((p) => p['house'] == house)
        .length;
  }

  // ═══════════════════════════════════════════════════
  // ALL DUES LIST — admin PDF download ke liye
  // ═══════════════════════════════════════════════════
  static List<Map<String, dynamic>> getAllHousesWithDues() {
    final now    = DateTime.now();
    final result = <Map<String, dynamic>>[];
    // 2025 se current year tak saare years check karo
    final startYear = 2025;
    final years = List.generate(
        now.year - startYear + 1, (i) => (startYear + i).toString());
    for (final house in allHouses) {
      int totalCount = 0;
      double totalDue = 0;
      Map<String, List<String>> duesByYear = {};
      for (final year in years) {
        final dues = getDuesMonths(house, year);
        if (dues.isNotEmpty) {
          duesByYear[year] = dues;
          totalCount += dues.length;
          totalDue   += dues.length * monthlyFee;
        }
      }
      if (totalCount == 0) continue;
      result.add({
        'house':      house,
        'duesByYear': duesByYear,
        'duesCount':  totalCount,
        'totalDue':   totalDue,
      });
    }
    result.sort((a, b) =>
        (b['duesCount'] as int).compareTo(a['duesCount'] as int));
    return result;
  }

  // ═══════════════════════════════════════════════════
  // ANALYTICS
  // ═══════════════════════════════════════════════════
  static double getCollectedInCalendarMonth(int monthNum, int year) {
    return allPayments.where((p) {
      final s = (p['date'] as String?) ?? '';
      if (s.isEmpty) return false;
      try {
        final parts = s.split('/');
        if (parts.length != 3) return false;
        return int.parse(parts[1]) == monthNum && int.parse(parts[2]) == year;
      } catch (_) { return false; }
    }).fold(0.0, (s, p) => s + (p['amount'] as double));
  }

  // ── Live refresh — call when data might be stale ──
  static Future<void> refreshPayments() async {
    await _loadPayments();
  }

  static Future<void> refreshAll() async {
    await _loadUsers();
    await _loadPayments();
  }

  static double calculateTotal() =>
      allPayments.fold(0.0, (s, p) => s + (p['amount'] as double));

  static double getMonthlyTotal(String month) =>
      allPayments.where((p) => p['month'] == month)
          .fold(0.0, (s, p) => s + (p['amount'] as double));

  static List<Map<String, dynamic>> getHistory(String house) =>
      houseHistory[house] ?? [];


  // ═══════════════════════════════════════════════════
  // MAINTENANCE TEAM — admin update kar sakta hai
  // ═══════════════════════════════════════════════════
  static List<Map<String, dynamic>> maintenanceTeam = [
    {
      'name':     'Imran Ali',
      'position': 'Head Technician',
      'phone':    '0300-1234567',
      'imagePath': '', // admin upload karega
    },
    {
      'name':     'Rashid Ahmed',
      'position': 'Electrician',
      'phone':    '0311-2345678',
      'imagePath': '',
    },
    {
      'name':     'Zafar Iqbal',
      'position': 'Plumber',
      'phone':    '0321-3456789',
      'imagePath': '',
    },
    {
      'name':     'Tariq Hassan',
      'position': 'Security Guard',
      'phone':    '0333-4567890',
      'imagePath': '',
    },
    {
      'name':     'Saleem Khan',
      'position': 'Cleaner / Sweeper',
      'phone':    '0345-5678901',
      'imagePath': '',
    },
  ];

  static Future<void> loadMaintenanceTeam() async {
    try {
      final snap = await _db.collection('maintenance_team').get();
      if (snap.docs.isNotEmpty) {
        maintenanceTeam = snap.docs.map((doc) {
          final d = doc.data();
          return {
            'id':       doc.id,
            'name':     d['name']     ?? '',
            'position': d['position'] ?? '',
            'phone':    d['phone']    ?? '',
            'imageUrl': d['imageUrl'] ?? d['imagePath'] ?? '', // ✅ Cloudinary URL
          };
        }).toList();
      }
    } catch (e) { debugPrint('loadMaintenanceTeam: $e'); }
  }

  static Future<void> saveMaintenanceMember(Map<String, dynamic> member) async {
    final id = member['id'] as String? ?? _db.collection('maintenance_team').doc().id;
    // imageUrl = Cloudinary permanent URL — yeh save karo
    await _db.collection('maintenance_team').doc(id).set({
      'name':     member['name']     ?? '',
      'position': member['position'] ?? '',
      'phone':    member['phone']    ?? '',
      'imageUrl': member['imageUrl'] ?? '', // ✅ Cloudinary URL — sab phones par dikhe ga
    });
  }

  static Future<void> deleteMaintenanceMember(String id) async {
    try {
      await _db.collection('maintenance_team').doc(id).delete();
    } catch (e) { debugPrint('_deleteMaintenanceMember: $e'); }
  }

  // ═══════════════════════════════════════════════════
  // ALL HOUSES
  // ═══════════════════════════════════════════════════
  static List<String> get allHouses {
    // Houses to remove
    const removed = {
      '47B','48A','48B','48C','48D',
      '49A','49B','49C','49D',
      '50A','50B','41D','39A','86A'
    };
    final list = <String>[];
    for (var i = 38; i <= 54; i++) {
      for (var b in ['A','B','C','D']) {
        final h = '$i$b';
        if (!removed.contains(h)) list.add(h);
      }
    }
    for (var i = 84; i <= 101; i++) {
      for (var b in ['A','B','C','D']) {
        final h = '$i$b';
        if (!removed.contains(h)) list.add(h);
      }
    }
    list.add('Jamatkhana');
    return list;
  }
}
