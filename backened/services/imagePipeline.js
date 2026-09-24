import { v2 as cloudinary } from "cloudinary";
import axios from "axios";

// Configure Cloudinary automatically using CLOUDINARY_URL from env
cloudinary.config();

const IMAGE_HEADERS = {
  "User-Agent": "MedicalKnowledgeHub/1.0 (https://studyapp.com; contact@studyapp.com)",
};

export async function uploadImageToCloudinary(imageUrl, category, slug, filename = "image") {
  try {
    // 1. Download image as buffer with User-Agent header (prevents 403 Forbidden)
    const response = await axios.get(imageUrl, {
      responseType: "arraybuffer",
      headers: IMAGE_HEADERS,
      timeout: 8000,
    });
    const buffer = Buffer.from(response.data);

    // 2. Setup upload folder structure
    const folder = `medical-dictionary/${category.toLowerCase().replace(/\s+/g, "-")}/${slug}`;

    // 3. Upload to Cloudinary using stream
    return new Promise((resolve) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder,
          public_id: filename,
          resource_type: "image",
          overwrite: true,
        },
        (error, result) => {
          if (error) {
            console.error("❌ Cloudinary upload error:", error.message);
            resolve(null);
          } else {
            const secureUrl = result.secure_url;
            const thumbnailUrl = secureUrl.replace("/upload/", "/upload/w_150,h_150,c_fill,q_auto,f_auto/");
            const mediumUrl = secureUrl.replace("/upload/", "/upload/w_600,c_limit,q_auto,f_auto/");

            console.log(`✅ Cloudinary upload success: ${secureUrl}`);
            resolve({
              url: secureUrl,
              thumbnailUrl,
              mediumUrl,
            });
          }
        }
      );

      uploadStream.end(buffer);
    });
  } catch (error) {
    console.error("❌ Image download/upload pipeline failed:", error.message);
    return null;
  }
}

export async function processTopicImages(rawImages, category, slug) {
  const processedImages = [];
  const imagesToProcess = rawImages.slice(0, 5);

  for (let i = 0; i < imagesToProcess.length; i++) {
    const img = imagesToProcess[i];
    try {
      console.log(`📸 Uploading image ${i + 1}/${imagesToProcess.length} for ${slug} to Cloudinary...`);
      const cloudinaryUrls = await uploadImageToCloudinary(img.url, category, slug, `med_img_${i}`);
      
      if (cloudinaryUrls) {
        processedImages.push({
          url: cloudinaryUrls.url,
          thumbnailUrl: cloudinaryUrls.thumbnailUrl,
          mediumUrl: cloudinaryUrls.mediumUrl,
          caption: img.caption || "Medical reference image",
          creator: img.creator || "Wikipedia / Wikimedia",
          license: img.license || "CC BY-SA 4.0",
          source: img.source || "Wikimedia Commons",
        });
      } else {
        // Fallback to raw image URL if Cloudinary upload fails
        processedImages.push({
          url: img.url,
          thumbnailUrl: img.thumbnailUrl || img.url,
          mediumUrl: img.mediumUrl || img.url,
          caption: img.caption || "Medical reference image",
          creator: img.creator || "Wikipedia / Wikimedia",
          license: img.license || "CC BY-SA 4.0",
          source: img.source || "Wikimedia Commons",
        });
      }
    } catch (e) {
      processedImages.push({
        url: img.url,
        thumbnailUrl: img.thumbnailUrl || img.url,
        mediumUrl: img.mediumUrl || img.url,
        caption: img.caption || "Medical reference image",
        creator: img.creator || "Wikipedia / Wikimedia",
        license: img.license || "CC BY-SA 4.0",
        source: img.source || "Wikimedia Commons",
      });
    }
  }

  return processedImages;
}
