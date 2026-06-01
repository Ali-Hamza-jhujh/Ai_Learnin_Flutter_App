import dotenv from "dotenv";
dotenv.config();

// ══════════════════════════════════════════
// CONSTANTS
// ══════════════════════════════════════════

const YT_API_BASE = "https://www.googleapis.com/youtube/v3";
const YT_API_KEY = process.env.YOUTUBE_API_KEY;

// ══════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════

// Convert ISO 8601 duration (PT1H2M3S) to readable string (1h 2m 3s)
const formatDuration = (iso) => {
  if (!iso) return "Unknown";
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return "Unknown";
  const h = match[1] ? `${match[1]}h ` : "";
  const m = match[2] ? `${match[2]}m ` : "";
  const s = match[3] ? `${match[3]}s` : "";
  return `${h}${m}${s}`.trim() || "Unknown";
};

// Convert view count to readable string (1.2M, 45K, etc.)
const formatViews = (count) => {
  if (!count) return "0";
  const n = parseInt(count);
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return n.toString();
};

// Score a video to rank it — prefers educational, longer, high-view content
const scoreVideo = (video) => {
  let score = 0;

  // View count — more views = more trusted
  const views = parseInt(video.statistics?.viewCount || 0);
  if (views > 1_000_000) score += 40;
  else if (views > 100_000) score += 30;
  else if (views > 10_000) score += 20;
  else if (views > 1_000) score += 10;

  // Duration — prefer lecture-length videos (5–60 min)
  const iso = video.contentDetails?.duration || "";
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (match) {
    const totalMinutes =
      (parseInt(match[1] || 0) * 60) +
      parseInt(match[2] || 0) +
      parseInt(match[3] || 0) / 60;
    if (totalMinutes >= 5 && totalMinutes <= 60) score += 30;
    else if (totalMinutes > 60) score += 15; // long lecture still useful
    else score += 5; // very short clip
  }

  // Like count — quality signal
  const likes = parseInt(video.statistics?.likeCount || 0);
  if (likes > 10_000) score += 20;
  else if (likes > 1_000) score += 10;
  else if (likes > 100) score += 5;

  // Channel credibility keywords in title/description
  const title = (video.snippet?.title || "").toLowerCase();
  const desc = (video.snippet?.description || "").toLowerCase();
  const eduKeywords = ["lecture", "tutorial", "course", "lesson", "explained",
    "learn", "teaching", "education", "university", "professor", "class"];
  for (const kw of eduKeywords) {
    if (title.includes(kw) || desc.includes(kw)) {
      score += 5;
      break; // only count once
    }
  }

  return score;
};

// ══════════════════════════════════════════
// MAIN SERVICE FUNCTIONS
// ══════════════════════════════════════════

// 1. Search YouTube for educational videos on a topic
const searchVideos = async (query, maxResults = 10, educationLevel = "") => {
  if (!YT_API_KEY) throw new Error("YOUTUBE_API_KEY not set in .env");

  // Add education level hint to query for better results
  const levelHint = educationLevel ? ` ${educationLevel}` : "";
  const searchQuery = `${query}${levelHint} lecture tutorial`;

  // Step 1 — Search for video IDs
  const searchUrl = new URL(`${YT_API_BASE}/search`);
  searchUrl.searchParams.set("part", "snippet");
  searchUrl.searchParams.set("q", searchQuery);
  searchUrl.searchParams.set("type", "video");
  searchUrl.searchParams.set("videoCategoryId", "27"); // 27 = Education category
  searchUrl.searchParams.set("relevanceLanguage", "en");
  searchUrl.searchParams.set("maxResults", maxResults.toString());
  searchUrl.searchParams.set("key", YT_API_KEY);

  const searchRes = await fetch(searchUrl.toString());
  if (!searchRes.ok) {
    const err = await searchRes.json();
    throw new Error(`YouTube search error: ${err.error?.message || searchRes.status}`);
  }

  const searchData = await searchRes.json();
  if (!searchData.items || searchData.items.length === 0) return [];

  const videoIds = searchData.items.map((item) => item.id.videoId).join(",");

  // Step 2 — Get full details (duration, views, likes) for all videos at once
  const detailsUrl = new URL(`${YT_API_BASE}/videos`);
  detailsUrl.searchParams.set("part", "snippet,contentDetails,statistics");
  detailsUrl.searchParams.set("id", videoIds);
  detailsUrl.searchParams.set("key", YT_API_KEY);

  const detailsRes = await fetch(detailsUrl.toString());
  if (!detailsRes.ok) {
    const err = await detailsRes.json();
    throw new Error(`YouTube details error: ${err.error?.message || detailsRes.status}`);
  }

  const detailsData = await detailsRes.json();

  // Step 3 — Format + score + sort videos
  const videos = detailsData.items.map((video) => ({
    videoId: video.id,
    title: video.snippet?.title || "",
    channelName: video.snippet?.channelTitle || "",
    channelId: video.snippet?.channelId || "",
    description: (video.snippet?.description || "").slice(0, 200),
    thumbnail: {
      default: video.snippet?.thumbnails?.default?.url || "",
      medium: video.snippet?.thumbnails?.medium?.url || "",
      high: video.snippet?.thumbnails?.high?.url || "",
    },
    url: `https://www.youtube.com/watch?v=${video.id}`,
    embedUrl: `https://www.youtube.com/embed/${video.id}`,
    duration: formatDuration(video.contentDetails?.duration),
    durationRaw: video.contentDetails?.duration || "",
    views: formatViews(video.statistics?.viewCount),
    viewsRaw: parseInt(video.statistics?.viewCount || 0),
    likes: formatViews(video.statistics?.likeCount),
    publishedAt: video.snippet?.publishedAt || "",
    score: scoreVideo(video), // internal ranking score
  }));

  // Sort by score — best educational videos first
  videos.sort((a, b) => b.score - a.score);

  // Remove internal score before sending to client
  return videos.map(({ score, ...v }) => v);
};

// 2. Get a single video's full details
const getVideoDetails = async (videoId) => {
  if (!YT_API_KEY) throw new Error("YOUTUBE_API_KEY not set in .env");

  const url = new URL(`${YT_API_BASE}/videos`);
  url.searchParams.set("part", "snippet,contentDetails,statistics");
  url.searchParams.set("id", videoId);
  url.searchParams.set("key", YT_API_KEY);

  const res = await fetch(url.toString());
  if (!res.ok) {
    const err = await res.json();
    throw new Error(`YouTube video details error: ${err.error?.message || res.status}`);
  }

  const data = await res.json();
  if (!data.items || data.items.length === 0) return null;

  const video = data.items[0];
  return {
    videoId: video.id,
    title: video.snippet?.title || "",
    channelName: video.snippet?.channelTitle || "",
    channelId: video.snippet?.channelId || "",
    description: video.snippet?.description || "",
    thumbnail: {
      default: video.snippet?.thumbnails?.default?.url || "",
      medium: video.snippet?.thumbnails?.medium?.url || "",
      high: video.snippet?.thumbnails?.high?.url || "",
      maxres: video.snippet?.thumbnails?.maxres?.url || "",
    },
    url: `https://www.youtube.com/watch?v=${video.id}`,
    embedUrl: `https://www.youtube.com/embed/${video.id}`,
    duration: formatDuration(video.contentDetails?.duration),
    views: formatViews(video.statistics?.viewCount),
    likes: formatViews(video.statistics?.likeCount),
    publishedAt: video.snippet?.publishedAt || "",
    tags: video.snippet?.tags || [],
  };
};

export { searchVideos, getVideoDetails };