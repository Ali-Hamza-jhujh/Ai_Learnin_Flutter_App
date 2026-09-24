import "../models/dictionary_model.dart";
import "api_client.dart";

class DictionaryService {
  // ─── Primary search: calls /api/dictionary/search (existing controller) ─────
  static Future<Map<String, dynamic>> search(String query, {String? categoryHint}) async {
    try {
      final params = <String, String>{"q": query};
      if (categoryHint != null && categoryHint.isNotEmpty) {
        params["category"] = categoryHint;
      }
      final response = await ApiClient.get("/api/dictionary/search", queryParams: params, timeout: const Duration(seconds: 45));
      if (response["item"] != null) {
        return {
          "item": DictionaryItem.fromJson(response["item"]),
          "source": response["source"] ?? "database",
        };
      }
      throw Exception("Invalid response format");
    } catch (e) {
      rethrow;
    }
  }

  // ─── Deep search: local DB → external APIs → save → return ──────────────────
  static Future<Map<String, dynamic>> deepSearch(String query) async {
    try {
      final response = await ApiClient.get("/api/medical/deep-search", queryParams: {"q": query}, timeout: const Duration(seconds: 45));
      if (response["data"] != null) {
        return {
          "item": DictionaryItem.fromJson(response["data"]),
          "source": response["source"] ?? "api_fetch",
        };
      }
      throw Exception("No data returned from deep search");
    } catch (e) {
      rethrow;
    }
  }

  // ─── Smart search: tries local first, falls back to deep search ─────────────
  static Future<Map<String, dynamic>> smartSearch(String query, {String? categoryHint}) async {
    try {
      return await search(query, categoryHint: categoryHint);
    } catch (_) {
      // Local search failed or returned no results → try deep search
      return await deepSearch(query);
    }
  }

  // ─── Get items by category ──────────────────────────────────────────────────
  static Future<List<DictionaryItem>> getByCategory(String category, {String? query}) async {
    try {
      final queryParams = <String, String>{};
      if (query != null && query.trim().isNotEmpty) {
        queryParams["q"] = query.trim();
      }
      final response = await ApiClient.get("/api/dictionary/category/$category", queryParams: queryParams);
      final List rawList = response is List ? response : (response["data"] is List ? response["data"] : []);
      final List<DictionaryItem> results = [];
      for (final x in rawList) {
        try {
          results.add(DictionaryItem.fromJson(Map<String, dynamic>.from(x as Map)));
        } catch (parseErr) {
          print("⚠️ Skipping unparseable item in $category: $parseErr");
        }
      }
      return results;
    } catch (e) {
      print("❌ Error in getByCategory: $e");
      return [];
    }
  }

  // ─── Autocomplete from /api/dictionary ──────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAutocomplete(String query) async {
    try {
      final response = await ApiClient.get("/api/dictionary/autocomplete", queryParams: {"q": query});
      final List rawList = response["data"] is List
          ? response["data"]
          : (response["suggestions"] is List ? response["suggestions"] : (response is List ? response : []));
      return rawList.map((x) => Map<String, dynamic>.from(x as Map)).toList();
    } catch (e) {
      print("❌ Error in getAutocomplete: $e");
      return [];
    }
  }

  // ─── Medical autocomplete (from /api/medical) ───────────────────────────────
  static Future<List<Map<String, dynamic>>> getMedicalAutocomplete(String query) async {
    try {
      final response = await ApiClient.get("/api/medical/autocomplete", queryParams: {"q": query});
      final List rawList = response["suggestions"] is List ? response["suggestions"] : [];
      return rawList.map((x) => Map<String, dynamic>.from(x as Map)).toList();
    } catch (e) {
      print("❌ Error in getMedicalAutocomplete: $e");
      return [];
    }
  }

  // ─── Get topic details ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTopicDetails(String slug) async {
    try {
      final response = await ApiClient.get("/api/dictionary/topic/$slug");
      if (response["item"] != null) {
        return {
          "item": DictionaryItem.fromJson(response["item"]),
          "isBookmarked": response["isBookmarked"] ?? false,
        };
      }
      throw Exception("Topic not found");
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get medical topic (from /api/medical — with external API data) ─────────
  static Future<DictionaryItem> getMedicalTopic(String slug) async {
    try {
      final response = await ApiClient.get("/api/medical/topic/$slug");
      if (response["data"] != null) {
        return DictionaryItem.fromJson(response["data"]);
      }
      throw Exception("Medical topic not found");
    } catch (e) {
      rethrow;
    }
  }

  // ─── Toggle bookmark ───────────────────────────────────────────────────────
  static Future<bool> toggleBookmark(String itemId) async {
    try {
      final response = await ApiClient.post("/api/dictionary/bookmark", body: {"itemId": itemId});
      return response["bookmarked"] ?? false;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get bookmarks ─────────────────────────────────────────────────────────
  static Future<List<DictionaryItem>> getBookmarks() async {
    try {
      final response = await ApiClient.get("/api/dictionary/bookmarks");
      final List rawList = response["data"] is List
          ? response["data"]
          : (response["bookmarks"] is List ? response["bookmarks"] : (response is List ? response : []));
      return rawList.map((x) => DictionaryItem.fromJson(Map<String, dynamic>.from(x as Map))).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Get stats ─────────────────────────────────────────────────────────────
  static Future<Map<String, List<DictionaryItem>>> getStats() async {
    try {
      final response = await ApiClient.get("/api/dictionary/stats");

      final trending = (response["trending"] as List?)?.map((x) => DictionaryItem.fromJson(Map<String, dynamic>.from(x as Map))).toList() ?? [];
      final popular = (response["popular"] as List?)?.map((x) => DictionaryItem.fromJson(Map<String, dynamic>.from(x as Map))).toList() ?? [];
      final recentlyAdded = (response["recentlyAdded"] as List?)?.map((x) => DictionaryItem.fromJson(Map<String, dynamic>.from(x as Map))).toList() ?? [];

      return {
        "trending": trending,
        "popular": popular,
        "recentlyAdded": recentlyAdded,
      };
    } catch (e) {
      return {
        "trending": [],
        "popular": [],
        "recentlyAdded": [],
      };
    }
  }

  // ─── Get random topic (word of the day) ─────────────────────────────────────
  static Future<DictionaryItem?> getRandomTopic() async {
    try {
      final response = await ApiClient.get("/api/medical/random");
      if (response["success"] == true && response["data"] != null) {
        return DictionaryItem.fromJson(response["data"]);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Force refresh topic data from external APIs ────────────────────────────
  static Future<DictionaryItem?> refreshTopic(String slug) async {
    try {
      final response = await ApiClient.post("/api/medical/refresh/$slug", body: {});
      if (response["data"] != null) {
        return DictionaryItem.fromJson(response["data"]);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Get medical categories with counts ─────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMedicalCategories() async {
    try {
      final response = await ApiClient.get("/api/medical/categories");
      final List categories = response["categories"] is List ? response["categories"] : [];
      return categories.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    } catch (e) {
      print("❌ Error in getMedicalCategories: $e");
      return [];
    }
  }

  // ─── Get related topics ─────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRelatedTopics(String slug) async {
    try {
      final response = await ApiClient.get("/api/medical/related/$slug");
      final List topics = response["relatedTopics"] is List ? response["relatedTopics"] : [];
      return topics.map((t) => Map<String, dynamic>.from(t as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Get trending topics ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTrending() async {
    try {
      final response = await ApiClient.get("/api/medical/trending");
      return {
        "mostSearched": (response["mostSearched"] as List?)
                ?.map((x) => Map<String, dynamic>.from(x as Map))
                .toList() ??
            [],
        "mostViewed": (response["mostViewed"] as List?)
                ?.map((x) => Map<String, dynamic>.from(x as Map))
                .toList() ??
            [],
      };
    } catch (e) {
      return {"mostSearched": [], "mostViewed": []};
    }
  }

  // ─── Admin: Delete a dictionary item ────────────────────────────────────────
  static Future<void> deleteItem(String itemId) async {
    await ApiClient.delete("/api/dictionary/item/$itemId");
  }

  static Future<Map<String, dynamic>> getImageGallery() async {
    try {
      final response = await ApiClient.get("/api/medical/images/gallery", timeout: const Duration(seconds: 30));
      
      final rawCategories = response["categories"];
      final List<Map<String, dynamic>> categories = [];
      
      if (rawCategories is List) {
        for (var c in rawCategories) {
          if (c is Map) {
             categories.add(Map<String, dynamic>.from(c));
          }
        }
      }

      return {
        "totalImages": response["totalImages"] ?? 0,
        "categoryCount": response["categoryCount"] ?? 0,
        "categories": categories,
      };
    } catch (e, stackTrace) {
      print("❌ Error in getImageGallery: $e");
      print(stackTrace);
      return {"totalImages": 0, "categoryCount": 0, "categories": []};
    }
  }
}
