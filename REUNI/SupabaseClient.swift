//
//  SupabaseClient.swift
//  REUNI
//
//  Supabase client configuration
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://skkaksjbnfxklivniqwy.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNra2Frc2pibmZ4a2xpdm5pcXd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxOTA3ODcsImV4cCI6MjA3NTc2Njc4N30.U9JZrDag3vtEnVBnk21hvB-Q9g31-qevNwGAxatRrgU"
)
