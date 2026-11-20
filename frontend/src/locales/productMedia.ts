const en = {
  title: "Customer-requested media", help: "Public HTTPS file URLs only. Mark Actual only for your own verified product photo/recording. Video URLs must point to playable files, not Facebook or YouTube pages.",
  add: "Add media", remove: "Remove", url: "Media URL", kind: "Media type", image: "Photo", video: "Video", authenticity: "Photo/recording source", actual: "Actual product (seller verified)", promotional: "Catalogue / promotional", variant: "Exact variant name (optional)", general: "Leave blank for general product media", links: "Facebook / product reference links", linksHelp: "One exact post or product URL per line. Unknown links are never scraped or guessed.",
};
const bn: typeof en = {
  title: "ক্রেতার চাওয়া ছবি ও ভিডিও", help: "পাবলিক HTTPS ফাইল লিংক দিন। নিজের যাচাই করা ছবি বা রেকর্ডিংকেই আসল চিহ্নিত করুন। ভিডিওর সরাসরি ফাইল লিংক দিন, ফেসবুক বা ইউটিউব পেজ নয়।",
  add: "ছবি/ভিডিও যোগ করুন", remove: "সরান", url: "মিডিয়া লিংক", kind: "ধরন", image: "ছবি", video: "ভিডিও", authenticity: "ছবি/রেকর্ডিংয়ের উৎস", actual: "আসল পণ্য (বিক্রেতার যাচাই করা)", promotional: "ক্যাটালগ / প্রচারণা", variant: "সঠিক ভ্যারিয়েন্টের নাম (ঐচ্ছিক)", general: "সাধারণ পণ্যের মিডিয়ার জন্য ফাঁকা রাখুন", links: "ফেসবুক / পণ্যের রেফারেন্স লিংক", linksHelp: "প্রতি লাইনে একটি সঠিক পোস্ট বা পণ্যের লিংক দিন। অজানা লিংক থেকে তথ্য অনুমান করা হয় না।",
};
export function productMediaMessages(language?: string) { return language === "bn" ? bn : en; }
