import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'http://127.0.0.1:54321'
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
})

// Database types (will be generated from Supabase CLI later)
export type Database = {
  public: {
    Tables: {
      companies: {
        Row: {
          id: string
          name: string
          slug: string
          logo_url: string | null
          stripe_customer_id: string | null
          status: 'active' | 'trial' | 'delinquent' | 'suspended'
          created_at: string
          updated_at: string
          delinquent_at: string | null
        }
        Insert: {
          id?: string
          name: string
          slug: string
          logo_url?: string | null
          stripe_customer_id?: string | null
          status?: 'active' | 'trial' | 'delinquent' | 'suspended'
          created_at?: string
          updated_at?: string
          delinquent_at?: string | null
        }
        Update: {
          id?: string
          name?: string
          slug?: string
          logo_url?: string | null
          stripe_customer_id?: string | null
          status?: 'active' | 'trial' | 'delinquent' | 'suspended'
          created_at?: string
          updated_at?: string
          delinquent_at?: string | null
        }
      }
      user_profiles: {
        Row: {
          id: string
          email: string
          name: string | null
          avatar_url: string | null
          default_company_id: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          email: string
          name?: string | null
          avatar_url?: string | null
          default_company_id?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string
          name?: string | null
          avatar_url?: string | null
          default_company_id?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      company_members: {
        Row: {
          user_id: string
          company_id: string
          role: 'admin' | 'user' | 'super_admin'
          joined_at: string
        }
        Insert: {
          user_id: string
          company_id: string
          role?: 'admin' | 'user' | 'super_admin'
          joined_at?: string
        }
        Update: {
          user_id?: string
          company_id?: string
          role?: 'admin' | 'user' | 'super_admin'
          joined_at?: string
        }
      }
      modules: {
        Row: {
          id: string
          slug: string
          name: string
          description: string | null
          latest_version: string
          base_price_cents: number
          per_user_price_cents: number
          is_active: boolean
          is_beta: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          slug: string
          name: string
          description?: string | null
          latest_version: string
          base_price_cents?: number
          per_user_price_cents?: number
          is_active?: boolean
          is_beta?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          slug?: string
          name?: string
          description?: string | null
          latest_version?: string
          base_price_cents?: number
          per_user_price_cents?: number
          is_active?: boolean
          is_beta?: boolean
          created_at?: string
          updated_at?: string
        }
      }
      company_modules: {
        Row: {
          company_id: string
          module_id: string
          enabled: boolean
          enabled_at: string
          billing_plan: string | null
          settings: Record<string, any>
        }
        Insert: {
          company_id: string
          module_id: string
          enabled?: boolean
          enabled_at?: string
          billing_plan?: string | null
          settings?: Record<string, any>
        }
        Update: {
          company_id?: string
          module_id?: string
          enabled?: boolean
          enabled_at?: string
          billing_plan?: string | null
          settings?: Record<string, any>
        }
      }
      notifications: {
        Row: {
          id: string
          user_id: string
          company_id: string | null
          type: string
          title: string
          message: string | null
          payload: Record<string, any>
          seen: boolean
          delivered_channels: string[]
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          company_id?: string | null
          type: string
          title: string
          message?: string | null
          payload?: Record<string, any>
          seen?: boolean
          delivered_channels?: string[]
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          company_id?: string | null
          type?: string
          title?: string
          message?: string | null
          payload?: Record<string, any>
          seen?: boolean
          delivered_channels?: string[]
          created_at?: string
        }
      }
      changelog_entries: {
        Row: {
          id: string
          title: string
          content: string
          version: string | null
          module_slug: string | null
          is_published: boolean
          published_at: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          title: string
          content: string
          version?: string | null
          module_slug?: string | null
          is_published?: boolean
          published_at?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          title?: string
          content?: string
          version?: string | null
          module_slug?: string | null
          is_published?: boolean
          published_at?: string | null
          created_at?: string
          updated_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      user_role: 'admin' | 'user' | 'super_admin'
      company_status: 'active' | 'trial' | 'delinquent' | 'suspended'
      subscription_status: 'active' | 'past_due' | 'canceled' | 'unpaid'
    }
  }
}
