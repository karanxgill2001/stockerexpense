import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inventory_item.dart';

class LowStockAlertService {
  LowStockAlertService._();

  static const int lowStockThreshold = InventoryItem.lowStockThreshold;
  static const String _inventorySnapshotKey = 'low_stock_inventory_snapshot';
  static bool _hasShownLaunchPopup = false;

  static Future<List<InventoryItem>> consumeLowStockItemsForPopup(
    List<InventoryItem> items,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final previousSnapshot = _decodeSnapshot(
      preferences.getString(_inventorySnapshotKey),
    );

    final currentSnapshot = <String, int>{};
    final currentLowStockItems = <InventoryItem>[];
    final newlyLowStockItems = <InventoryItem>[];

    for (final item in items) {
      final key = _itemKey(item);
      if (key.isEmpty) {
        continue;
      }

      currentSnapshot[key] = item.quantity;
      if (item.quantity <= lowStockThreshold) {
        currentLowStockItems.add(item);
      }

      final previousQuantity = previousSnapshot[key];
      if (previousQuantity == null) {
        continue;
      }

      if (previousQuantity > lowStockThreshold &&
          item.quantity <= lowStockThreshold) {
        newlyLowStockItems.add(item);
      }
    }

    await preferences.setString(
      _inventorySnapshotKey,
      jsonEncode(currentSnapshot),
    );

    if (!_hasShownLaunchPopup) {
      _hasShownLaunchPopup = true;
      currentLowStockItems.sort((a, b) => a.quantity.compareTo(b.quantity));
      return currentLowStockItems;
    }

    newlyLowStockItems.sort((a, b) => a.quantity.compareTo(b.quantity));
    return newlyLowStockItems;
  }

  static Future<void> playAlertSound() async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource('audio/critical_hit.mp3'));
    } finally {
      player.onPlayerComplete.first.then((_) => player.dispose());
    }
  }

  static Map<String, int> _decodeSnapshot(String? rawSnapshot) {
    if (rawSnapshot == null || rawSnapshot.trim().isEmpty) {
      return const <String, int>{};
    }

    final decoded = jsonDecode(rawSnapshot);
    if (decoded is! Map) {
      return const <String, int>{};
    }

    final snapshot = <String, int>{};
    for (final entry in decoded.entries) {
      final quantity = int.tryParse(entry.value.toString());
      if (quantity == null) {
        continue;
      }
      snapshot[entry.key.toString()] = quantity;
    }
    return snapshot;
  }

  static String _itemKey(InventoryItem item) {
    final sku = item.sku.trim().toLowerCase();
    if (sku.isNotEmpty) {
      return 'sku::$sku';
    }

    final itemName = item.itemName.trim().toLowerCase();
    if (itemName.isNotEmpty) {
      return 'name::$itemName';
    }

    return '';
  }
}
