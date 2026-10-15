const messages = {
  en: {
    title: "Product images",
    help: "Add HTTPS image links. The first image is the cover. Links must remain publicly accessible; files are not uploaded to ChatCart.",
    url: "Image URL", add: "Add image", remove: "Remove image", cover: "Cover", makeCover: "Use as cover",
    invalid: "Enter an HTTPS image link without login details or a custom port.",
    duplicate: "This image is already in the gallery.",
    unavailable: "Image unavailable", empty: "No product image",
    imageAlt: (name: string) => `${name} product image`,
  },
  bn: {
    title: "পণ্যের ছবি",
    help: "HTTPS ছবির লিংক যোগ করুন। প্রথম ছবিটি কভার। লিংক সবার জন্য উন্মুক্ত থাকতে হবে; ChatCart-এ ফাইল আপলোড হবে না।",
    url: "ছবির লিংক", add: "ছবি যোগ করুন", remove: "ছবি সরান", cover: "কভার", makeCover: "কভার হিসেবে ব্যবহার করুন",
    invalid: "লগইন তথ্য বা কাস্টম পোর্ট ছাড়া HTTPS ছবির লিংক দিন।",
    duplicate: "এই ছবিটি ইতিমধ্যে যোগ করা আছে।",
    unavailable: "ছবি পাওয়া যাচ্ছে না", empty: "পণ্যের ছবি নেই",
    imageAlt: (name: string) => `${name} পণ্যের ছবি`,
  },
};

export function productImageMessages(language?: string) {
  return language === "bn" || language === "bangla" ? messages.bn : messages.en;
}
