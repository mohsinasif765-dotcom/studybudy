import 'package:flutter/foundation.dart';

class AppErrorHandler {
  /// 🛡️ Raw Error ko User-Friendly Message mein convert karta hai
  static String getFriendlyMessage(dynamic error) {
    final String rawError = error.toString().toLowerCase();

    // 1. 🔍 Sabse pehle Raw Error ko Console mein chupke se Log karo (Sirf Developer ke liye)
    debugPrint("🔴 [INTERNAL LOG] RAW ERROR: $error");

    // 2. 🌍 Network / Internet Errors
    if (rawError.contains("socketexception") || 
        rawError.contains("connection timed out") || 
        rawError.contains("clientoffline") ||
        rawError.contains("network request failed")) {
      return "No internet connection. Please check your WiFi/Data.";
    }

    // 3. 🤖 AI & Model Errors (OpenAI, Gemini, etc.)
    if (rawError.contains("model") && (rawError.contains("not found") || rawError.contains("does not exist"))) {
      // User ko technical details nahi, solution batao
      return "The selected AI Model is currently unavailable. Please switch to a different provider (Gemini/OpenAI) in Settings.";
    }
    if (rawError.contains("quota") || rawError.contains("insufficient quota") || rawError.contains("429")) {
      return "AI Service is receiving high traffic. Please try again in a few moments.";
    }
    if (rawError.contains("api key") || rawError.contains("unauthenticated")) {
      return "Service configuration issue. Please contact support.";
    }

    // 4. 🗄️ Database / Backend Errors
    if (rawError.contains("infinite recursion") || rawError.contains("policy")) {
      // Infinite loop wala error user ko darana nahi chahiye
      return "System security policies are updating. Please refresh the app.";
    }
    if (rawError.contains("row-level security") || rawError.contains("permission denied")) {
      return "You do not have permission to perform this action.";
    }

    // 5. 📄 File & PDF Errors
    if (rawError.contains("password protected") || rawError.contains("encrypted")) {
      return "This PDF is password protected. Please upload an unlocked file.";
    }
    if (rawError.contains("scanned pdf") || rawError.contains("no text found")) {
      return "This document appears to be an image. Please use the 'Scan Notes' camera feature instead.";
    }
    if (rawError.contains("file format") || rawError.contains("corrupted")) {
      return "Invalid file format. Please upload a valid PDF or Image.";
    }

    // 6. 🤷‍♂️ Generic Fallback (Default)
    // Agar koi ajeeb error ho jo humein nahi pata, to User ko "Something went wrong" dikhao
    return "Something went wrong. Please try again.";
  }
}