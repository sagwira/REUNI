//
//  SupabaseClient.swift
//  REUNI
//
//  Supabase client configuration
//  SECURITY: API keys are loaded from Info.plist, NOT hardcoded
//

import Foundation
@_exported import Supabase

// MARK: - Secure Supabase Client
// API key is loaded from Info.plist to keep it out of git
let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)
