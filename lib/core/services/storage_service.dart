import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_tiles_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _savedTilesKey = 'saved_tiles';
  static const String _savedBuildingsKey = 'saved_buildings';

  // Save tile ID to local storage
  Future<void> saveTile(int tileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTiles = prefs.getStringList(_savedTilesKey) ?? [];

      if (!savedTiles.contains(tileId.toString())) {
        savedTiles.add(tileId.toString());
        await prefs.setStringList(_savedTilesKey, savedTiles);
        print('✅ Tile $tileId saved to local storage');
      }
    } catch (e) {
      print('❌ Error saving tile: $e');
    }
  }

  // Save building ID to local storage
  Future<void> saveBuilding(int buildingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBuildings = prefs.getStringList(_savedBuildingsKey) ?? [];

      if (!savedBuildings.contains(buildingId.toString())) {
        savedBuildings.add(buildingId.toString());
        await prefs.setStringList(_savedBuildingsKey, savedBuildings);
        print('✅ Building $buildingId saved to local storage');
      }
    } catch (e) {
      print('❌ Error saving building: $e');
    }
  }

  // Remove tile ID from local storage
  Future<void> unsaveTile(int tileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTiles = prefs.getStringList(_savedTilesKey) ?? [];

      savedTiles.remove(tileId.toString());
      await prefs.setStringList(_savedTilesKey, savedTiles);
      print('✅ Tile $tileId removed from local storage');
    } catch (e) {
      print('❌ Error unsaving tile: $e');
    }
  }

  // Remove building ID from local storage
  Future<void> unsaveBuilding(int buildingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBuildings = prefs.getStringList(_savedBuildingsKey) ?? [];

      savedBuildings.remove(buildingId.toString());
      await prefs.setStringList(_savedBuildingsKey, savedBuildings);
      print('✅ Building $buildingId removed from local storage');
    } catch (e) {
      print('❌ Error unsaving building: $e');
    }
  }

  // Get all saved tile IDs
  Future<Set<int>> getSavedTileIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTiles = prefs.getStringList(_savedTilesKey) ?? [];
      return savedTiles.map((id) => int.parse(id)).toSet();
    } catch (e) {
      print('❌ Error getting saved tile IDs: $e');
      return <int>{};
    }
  }

  // Get all saved building IDs
  Future<Set<int>> getSavedBuildingIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBuildings = prefs.getStringList(_savedBuildingsKey) ?? [];
      return savedBuildings.map((id) => int.parse(id)).toSet();
    } catch (e) {
      print('❌ Error getting saved building IDs: $e');
      return <int>{};
    }
  }

  // Check if a tile is saved
  Future<bool> isTileSaved(int tileId) async {
    final savedTileIds = await getSavedTileIds();
    return savedTileIds.contains(tileId);
  }

  // Check if a building is saved
  Future<bool> isBuildingSaved(int buildingId) async {
    final savedBuildingIds = await getSavedBuildingIds();
    return savedBuildingIds.contains(buildingId);
  }

  // Get saved tiles with their isSaved flag set to true
  Future<List<MapTile>> getSavedTiles(List<MapTile> allTiles) async {
    try {
      final savedTileIds = await getSavedTileIds();
      return allTiles.where((tile) => savedTileIds.contains(tile.id)).map((tile) {
        return tile.copyWith(isSaved: true);
      }).toList();
    } catch (e) {
      print('❌ Error getting saved tiles: $e');
      return [];
    }
  }

  // Get saved buildings with their isSaved flag set to true
  Future<List<Building>> getSavedBuildings(List<Building> allBuildings) async {
    try {
      final savedBuildingIds = await getSavedBuildingIds();
      return allBuildings.where((building) => savedBuildingIds.contains(building.id)).map((building) {
        return building.copyWith(isSaved: true);
      }).toList();
    } catch (e) {
      print('❌ Error getting saved buildings: $e');
      return [];
    }
  }

  // Update all tiles and buildings with their saved status
  Future<void> updateSavedStatus(List<MapTile> tiles, List<Building> buildings) async {
    try {
      final savedTileIds = await getSavedTileIds();
      final savedBuildingIds = await getSavedBuildingIds();

      // Update tiles
      for (final tile in tiles) {
        tile.isSaved = savedTileIds.contains(tile.id);
      }

      // Update buildings
      for (final building in buildings) {
        building.isSaved = savedBuildingIds.contains(building.id);
      }

      print('✅ Updated saved status for ${tiles.length} tiles and ${buildings.length} buildings');
    } catch (e) {
      print('❌ Error updating saved status: $e');
    }
  }

  // Clear all saved data
  Future<void> clearAllSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedTilesKey);
      await prefs.remove(_savedBuildingsKey);
      print('✅ Cleared all saved data');
    } catch (e) {
      print('❌ Error clearing saved data: $e');
    }
  }

  // Get statistics
  Future<Map<String, int>> getSavedStats() async {
    try {
      final savedTileIds = await getSavedTileIds();
      final savedBuildingIds = await getSavedBuildingIds();

      return {
        'savedTiles': savedTileIds.length,
        'savedBuildings': savedBuildingIds.length,
        'totalSaved': savedTileIds.length + savedBuildingIds.length,
      };
    } catch (e) {
      print('❌ Error getting saved stats: $e');
      return {
        'savedTiles': 0,
        'savedBuildings': 0,
        'totalSaved': 0,
      };
    }
  }
}