const messages = {
  en: {
    title: "Assistant automation", pause: "Pause AI for all chats", resume: "Resume AI for this business",
    paused: "AI paused for all existing and new chats. Staff can still reply.",
    help: "Pausing stops automated text and photo replies across this business. Messages keep arriving. Resuming does not release skipped bot replies or resume individually taken-over chats. A reply already sent to the provider cannot be recalled.",
    active: "AI is enabled. Individual chat takeovers still apply.", saving: "Saving…",
    confirmResume: "Resume AI for this business? Individually taken-over chats will remain manual.",
    confirm: "Confirm resume", cancel: "Cancel",
  },
  bn: {
    title: "সহকারীর অটোমেশন", pause: "সব চ্যাটে AI বন্ধ করুন", resume: "এই ব্যবসায় AI চালু করুন",
    paused: "পুরোনো ও নতুন সব চ্যাটে AI বন্ধ আছে। কর্মীরা উত্তর দিতে পারবেন।",
    help: "বন্ধ থাকলে এই ব্যবসায় স্বয়ংক্রিয় টেক্সট ও ছবির উত্তর যাবে না। নতুন বার্তা আসবে। চালু করলে বাদ দেওয়া উত্তর বা আলাদাভাবে নেওয়া চ্যাট চালু হবে না। ইতিমধ্যে পাঠানো উত্তর ফেরানো যাবে না।",
    active: "AI চালু আছে। আলাদা চ্যাটের টেকওভার বহাল থাকবে।", saving: "সংরক্ষণ হচ্ছে…",
    confirmResume: "এই ব্যবসায় AI চালু করবেন? আলাদাভাবে নেওয়া চ্যাট ম্যানুয়াল থাকবে।",
    confirm: "চালু করুন", cancel: "বাতিল",
  },
};

export function automationMessages(language) {
  return ["bn", "bengali", "bangla"].includes(language) ? messages.bn : messages.en;
}
