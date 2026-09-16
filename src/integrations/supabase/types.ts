export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      admin_audit_logs: {
        Row: {
          action: string
          admin_id: string
          created_at: string
          entity_id: string
          entity_type: string
          id: number
          ip_address: string | null
          new_state: Json | null
          previous_state: Json | null
          user_agent: string | null
        }
        Insert: {
          action: string
          admin_id: string
          created_at?: string
          entity_id: string
          entity_type: string
          id?: number
          ip_address?: string | null
          new_state?: Json | null
          previous_state?: Json | null
          user_agent?: string | null
        }
        Update: {
          action?: string
          admin_id?: string
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: number
          ip_address?: string | null
          new_state?: Json | null
          previous_state?: Json | null
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "admin_audit_logs_admin_id_fkey"
            columns: ["admin_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      brands: {
        Row: {
          created_at: string
          established_year: number | null
          id: string
          is_active: boolean
          location: string | null
          logo_url: string | null
          name: string
          seller_id: string
          slug: string
          story: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          established_year?: number | null
          id?: string
          is_active?: boolean
          location?: string | null
          logo_url?: string | null
          name: string
          seller_id: string
          slug: string
          story?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          established_year?: number | null
          id?: string
          is_active?: boolean
          location?: string | null
          logo_url?: string | null
          name?: string
          seller_id?: string
          slug?: string
          story?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "brands_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "brands_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
        ]
      }
      cart_lines: {
        Row: {
          cart_id: string
          created_at: string
          id: string
          quantity: number
          updated_at: string
          variant_id: string
        }
        Insert: {
          cart_id: string
          created_at?: string
          id?: string
          quantity: number
          updated_at?: string
          variant_id: string
        }
        Update: {
          cart_id?: string
          created_at?: string
          id?: string
          quantity?: number
          updated_at?: string
          variant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "cart_lines_cart_id_fkey"
            columns: ["cart_id"]
            isOneToOne: false
            referencedRelation: "carts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_lines_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      carts: {
        Row: {
          created_at: string
          id: string
          session_id: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          session_id?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          session_id?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "carts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          slug: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          slug: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          sort_order?: number
        }
        Relationships: []
      }
      checkout_quotes: {
        Row: {
          created_at: string
          discount_paise: number
          expires_at: string
          id: string
          session_id: string | null
          shipping_address: Json
          shipping_fee_paise: number
          status: Database["public"]["Enums"]["checkout_quote_status"]
          subtotal_paise: number
          tax_paise: number
          total_payable_paise: number
          user_id: string | null
        }
        Insert: {
          created_at?: string
          discount_paise?: number
          expires_at: string
          id?: string
          session_id?: string | null
          shipping_address: Json
          shipping_fee_paise?: number
          status?: Database["public"]["Enums"]["checkout_quote_status"]
          subtotal_paise: number
          tax_paise?: number
          total_payable_paise: number
          user_id?: string | null
        }
        Update: {
          created_at?: string
          discount_paise?: number
          expires_at?: string
          id?: string
          session_id?: string | null
          shipping_address?: Json
          shipping_fee_paise?: number
          status?: Database["public"]["Enums"]["checkout_quote_status"]
          subtotal_paise?: number
          tax_paise?: number
          total_payable_paise?: number
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "checkout_quotes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_addresses: {
        Row: {
          city: string
          country: string
          created_at: string
          full_name: string
          id: string
          is_active: boolean
          is_default: boolean
          line1: string
          line2: string | null
          phone: string
          pincode: string
          state: string
          updated_at: string
          user_id: string
        }
        Insert: {
          city: string
          country?: string
          created_at?: string
          full_name: string
          id?: string
          is_active?: boolean
          is_default?: boolean
          line1: string
          line2?: string | null
          phone: string
          pincode: string
          state: string
          updated_at?: string
          user_id: string
        }
        Update: {
          city?: string
          country?: string
          created_at?: string
          full_name?: string
          id?: string
          is_active?: boolean
          is_default?: boolean
          line1?: string
          line2?: string | null
          phone?: string
          pincode?: string
          state?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_addresses_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_wishlist: {
        Row: {
          created_at: string
          id: string
          product_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          product_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          product_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_wishlist_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_wishlist_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_wishlist_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      designers: {
        Row: {
          bio: string | null
          brand_id: string | null
          created_at: string
          id: string
          is_active: boolean
          name: string
          philosophy: string | null
          portrait_url: string | null
          slug: string
          updated_at: string
        }
        Insert: {
          bio?: string | null
          brand_id?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          philosophy?: string | null
          portrait_url?: string | null
          slug: string
          updated_at?: string
        }
        Update: {
          bio?: string | null
          brand_id?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          philosophy?: string | null
          portrait_url?: string | null
          slug?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "designers_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "designers_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["brand_id"]
          },
        ]
      }
      financial_ledger_entries: {
        Row: {
          account_type: Database["public"]["Enums"]["ledger_account_type"]
          amount_paise: number
          created_at: string
          currency: string
          entry_type: Database["public"]["Enums"]["ledger_entry_type"]
          id: number
          order_id: string | null
          payment_id: string | null
          payout_id: string | null
          reference_note: string | null
          refund_id: string | null
          seller_id: string | null
          sub_order_id: string | null
          transaction_group_id: string
        }
        Insert: {
          account_type: Database["public"]["Enums"]["ledger_account_type"]
          amount_paise: number
          created_at?: string
          currency?: string
          entry_type: Database["public"]["Enums"]["ledger_entry_type"]
          id?: number
          order_id?: string | null
          payment_id?: string | null
          payout_id?: string | null
          reference_note?: string | null
          refund_id?: string | null
          seller_id?: string | null
          sub_order_id?: string | null
          transaction_group_id: string
        }
        Update: {
          account_type?: Database["public"]["Enums"]["ledger_account_type"]
          amount_paise?: number
          created_at?: string
          currency?: string
          entry_type?: Database["public"]["Enums"]["ledger_entry_type"]
          id?: number
          order_id?: string | null
          payment_id?: string | null
          payout_id?: string | null
          reference_note?: string | null
          refund_id?: string | null
          seller_id?: string | null
          sub_order_id?: string | null
          transaction_group_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "financial_ledger_entries_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_ledger_entries_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payment_transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_ledger_entries_payout_id_fkey"
            columns: ["payout_id"]
            isOneToOne: false
            referencedRelation: "payout_statements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_ledger_entries_refund_id_fkey"
            columns: ["refund_id"]
            isOneToOne: false
            referencedRelation: "refund_transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_ledger_entries_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_ledger_entries_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_ledger_entries_sub_order_id_fkey"
            columns: ["sub_order_id"]
            isOneToOne: false
            referencedRelation: "seller_sub_orders"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_audit_log: {
        Row: {
          actor_id: string | null
          change_type: string
          created_at: string
          id: number
          quantity_delta: number
          quantity_on_hand_after: number
          quantity_reserved_after: number
          reference_id: string | null
          variant_id: string
        }
        Insert: {
          actor_id?: string | null
          change_type: string
          created_at?: string
          id?: number
          quantity_delta: number
          quantity_on_hand_after: number
          quantity_reserved_after: number
          reference_id?: string | null
          variant_id: string
        }
        Update: {
          actor_id?: string | null
          change_type?: string
          created_at?: string
          id?: number
          quantity_delta?: number
          quantity_on_hand_after?: number
          quantity_reserved_after?: number
          reference_id?: string | null
          variant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_audit_log_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_audit_log_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_items: {
        Row: {
          created_at: string
          id: string
          low_stock_threshold: number
          quantity_on_hand: number
          quantity_reserved: number
          updated_at: string
          variant_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          low_stock_threshold?: number
          quantity_on_hand?: number
          quantity_reserved?: number
          updated_at?: string
          variant_id: string
        }
        Update: {
          created_at?: string
          id?: string
          low_stock_threshold?: number
          quantity_on_hand?: number
          quantity_reserved?: number
          updated_at?: string
          variant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_items_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: true
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_reservations: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          quantity: number
          quote_id: string
          status: Database["public"]["Enums"]["inventory_reservation_status"]
          updated_at: string
          variant_id: string
        }
        Insert: {
          created_at?: string
          expires_at: string
          id?: string
          quantity: number
          quote_id: string
          status?: Database["public"]["Enums"]["inventory_reservation_status"]
          updated_at?: string
          variant_id: string
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          quantity?: number
          quote_id?: string
          status?: Database["public"]["Enums"]["inventory_reservation_status"]
          updated_at?: string
          variant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_reservations_quote_id_fkey"
            columns: ["quote_id"]
            isOneToOne: false
            referencedRelation: "checkout_quotes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_reservations_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      media_assets: {
        Row: {
          alt_text: string | null
          aspect_ratio: string | null
          asset_url: string
          created_at: string
          id: string
          product_id: string
          slot_role: Database["public"]["Enums"]["media_slot_role"]
          sort_order: number
          thumbnail_url: string | null
        }
        Insert: {
          alt_text?: string | null
          aspect_ratio?: string | null
          asset_url: string
          created_at?: string
          id?: string
          product_id: string
          slot_role?: Database["public"]["Enums"]["media_slot_role"]
          sort_order?: number
          thumbnail_url?: string | null
        }
        Update: {
          alt_text?: string | null
          aspect_ratio?: string | null
          asset_url?: string
          created_at?: string
          id?: string
          product_id?: string
          slot_role?: Database["public"]["Enums"]["media_slot_role"]
          sort_order?: number
          thumbnail_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "media_assets_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "media_assets_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["id"]
          },
        ]
      }
      merchandising_slots: {
        Row: {
          created_at: string
          end_at: string | null
          id: string
          image_url: string
          is_active: boolean
          slot_key: string
          sort_order: number
          start_at: string | null
          subtitle: string | null
          target_url: string | null
          title: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          end_at?: string | null
          id?: string
          image_url: string
          is_active?: boolean
          slot_key: string
          sort_order?: number
          start_at?: string | null
          subtitle?: string | null
          target_url?: string | null
          title?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          end_at?: string | null
          id?: string
          image_url?: string
          is_active?: boolean
          slot_key?: string
          sort_order?: number
          start_at?: string | null
          subtitle?: string | null
          target_url?: string | null
          title?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      mto_requests: {
        Row: {
          created_at: string
          customer_email: string
          customer_name: string
          customer_phone: string
          id: string
          measurements: Json
          notes: string | null
          product_id: string
          quote_price_paise: number | null
          reference_number: string
          status: Database["public"]["Enums"]["mto_request_status"]
          target_date: string | null
          updated_at: string
          user_id: string | null
          variant_id: string | null
        }
        Insert: {
          created_at?: string
          customer_email: string
          customer_name: string
          customer_phone: string
          id?: string
          measurements: Json
          notes?: string | null
          product_id: string
          quote_price_paise?: number | null
          reference_number: string
          status?: Database["public"]["Enums"]["mto_request_status"]
          target_date?: string | null
          updated_at?: string
          user_id?: string | null
          variant_id?: string | null
        }
        Update: {
          created_at?: string
          customer_email?: string
          customer_name?: string
          customer_phone?: string
          id?: string
          measurements?: Json
          notes?: string | null
          product_id?: string
          quote_price_paise?: number | null
          reference_number?: string
          status?: Database["public"]["Enums"]["mto_request_status"]
          target_date?: string | null
          updated_at?: string
          user_id?: string | null
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "mto_requests_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mto_requests_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mto_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mto_requests_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_outbox: {
        Row: {
          attempts: number
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at: string
          error_message: string | null
          id: number
          max_attempts: number
          next_retry_at: string
          payload: Json
          recipient: string
          sent_at: string | null
          status: Database["public"]["Enums"]["notification_status"]
          template_key: string
        }
        Insert: {
          attempts?: number
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          error_message?: string | null
          id?: number
          max_attempts?: number
          next_retry_at?: string
          payload: Json
          recipient: string
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          template_key: string
        }
        Update: {
          attempts?: number
          channel?: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          error_message?: string | null
          id?: number
          max_attempts?: number
          next_retry_at?: string
          payload?: Json
          recipient?: string
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          template_key?: string
        }
        Relationships: []
      }
      occasions: {
        Row: {
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          slug: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          slug: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          sort_order?: number
        }
        Relationships: []
      }
      order_items: {
        Row: {
          color: string
          created_at: string
          id: string
          product_title: string
          quantity: number
          size: string
          sub_order_id: string
          total_price_paise: number
          unit_price_paise: number
          variant_id: string
          variant_sku: string
        }
        Insert: {
          color: string
          created_at?: string
          id?: string
          product_title: string
          quantity: number
          size: string
          sub_order_id: string
          total_price_paise: number
          unit_price_paise: number
          variant_id: string
          variant_sku: string
        }
        Update: {
          color?: string
          created_at?: string
          id?: string
          product_title?: string
          quantity?: number
          size?: string
          sub_order_id?: string
          total_price_paise?: number
          unit_price_paise?: number
          variant_id?: string
          variant_sku?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_items_sub_order_id_fkey"
            columns: ["sub_order_id"]
            isOneToOne: false
            referencedRelation: "seller_sub_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      order_status_history: {
        Row: {
          actor_id: string | null
          created_at: string
          from_status: string | null
          id: number
          notes: string | null
          order_id: string | null
          sub_order_id: string | null
          to_status: string
        }
        Insert: {
          actor_id?: string | null
          created_at?: string
          from_status?: string | null
          id?: number
          notes?: string | null
          order_id?: string | null
          sub_order_id?: string | null
          to_status: string
        }
        Update: {
          actor_id?: string | null
          created_at?: string
          from_status?: string | null
          id?: number
          notes?: string | null
          order_id?: string | null
          sub_order_id?: string | null
          to_status?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_status_history_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_status_history_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_status_history_sub_order_id_fkey"
            columns: ["sub_order_id"]
            isOneToOne: false
            referencedRelation: "seller_sub_orders"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          created_at: string
          discount_paise: number
          id: string
          order_number: string
          quote_id: string | null
          shipping_address: Json
          shipping_fee_paise: number
          status: Database["public"]["Enums"]["order_status"]
          subtotal_paise: number
          tax_paise: number
          total_amount_paise: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          discount_paise?: number
          id?: string
          order_number: string
          quote_id?: string | null
          shipping_address: Json
          shipping_fee_paise?: number
          status?: Database["public"]["Enums"]["order_status"]
          subtotal_paise: number
          tax_paise?: number
          total_amount_paise: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          discount_paise?: number
          id?: string
          order_number?: string
          quote_id?: string | null
          shipping_address?: Json
          shipping_fee_paise?: number
          status?: Database["public"]["Enums"]["order_status"]
          subtotal_paise?: number
          tax_paise?: number
          total_amount_paise?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "orders_quote_id_fkey"
            columns: ["quote_id"]
            isOneToOne: false
            referencedRelation: "checkout_quotes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_transactions: {
        Row: {
          amount_paise: number
          created_at: string
          currency: string
          gateway: string
          gateway_order_id: string
          gateway_payment_id: string | null
          gateway_signature: string | null
          id: string
          order_id: string
          status: Database["public"]["Enums"]["payment_transaction_status"]
          updated_at: string
        }
        Insert: {
          amount_paise: number
          created_at?: string
          currency?: string
          gateway?: string
          gateway_order_id: string
          gateway_payment_id?: string | null
          gateway_signature?: string | null
          id?: string
          order_id: string
          status?: Database["public"]["Enums"]["payment_transaction_status"]
          updated_at?: string
        }
        Update: {
          amount_paise?: number
          created_at?: string
          currency?: string
          gateway?: string
          gateway_order_id?: string
          gateway_payment_id?: string | null
          gateway_signature?: string | null
          id?: string
          order_id?: string
          status?: Database["public"]["Enums"]["payment_transaction_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_transactions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      payout_statements: {
        Row: {
          authorized_by: string | null
          bank_utr_number: string | null
          commission_deductions_paise: number
          created_at: string
          gross_sales_paise: number
          id: string
          logistics_deductions_paise: number
          net_payout_paise: number
          razorpay_payout_id: string | null
          refund_deductions_paise: number
          seller_id: string
          settlement_period_end: string
          settlement_period_start: string
          statement_number: string
          status: Database["public"]["Enums"]["payout_statement_status"]
          tcs_deductions_paise: number
          tds_deductions_paise: number
          updated_at: string
        }
        Insert: {
          authorized_by?: string | null
          bank_utr_number?: string | null
          commission_deductions_paise: number
          created_at?: string
          gross_sales_paise: number
          id?: string
          logistics_deductions_paise: number
          net_payout_paise: number
          razorpay_payout_id?: string | null
          refund_deductions_paise: number
          seller_id: string
          settlement_period_end: string
          settlement_period_start: string
          statement_number: string
          status?: Database["public"]["Enums"]["payout_statement_status"]
          tcs_deductions_paise: number
          tds_deductions_paise: number
          updated_at?: string
        }
        Update: {
          authorized_by?: string | null
          bank_utr_number?: string | null
          commission_deductions_paise?: number
          created_at?: string
          gross_sales_paise?: number
          id?: string
          logistics_deductions_paise?: number
          net_payout_paise?: number
          razorpay_payout_id?: string | null
          refund_deductions_paise?: number
          seller_id?: string
          settlement_period_end?: string
          settlement_period_start?: string
          statement_number?: string
          status?: Database["public"]["Enums"]["payout_statement_status"]
          tcs_deductions_paise?: number
          tds_deductions_paise?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payout_statements_authorized_by_fkey"
            columns: ["authorized_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payout_statements_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payout_statements_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
        ]
      }
      product_occasions: {
        Row: {
          created_at: string
          occasion_id: string
          product_id: string
        }
        Insert: {
          created_at?: string
          occasion_id: string
          product_id: string
        }
        Update: {
          created_at?: string
          occasion_id?: string
          product_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_occasions_occasion_id_fkey"
            columns: ["occasion_id"]
            isOneToOne: false
            referencedRelation: "occasions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_occasions_occasion_id_fkey"
            columns: ["occasion_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["occasion_id"]
          },
          {
            foreignKeyName: "product_occasions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_occasions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_reviews: {
        Row: {
          body: string
          created_at: string
          id: string
          is_verified_purchase: boolean
          moderated_by: string | null
          order_id: string | null
          product_id: string
          rating: number
          status: Database["public"]["Enums"]["review_status"]
          title: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          is_verified_purchase?: boolean
          moderated_by?: string | null
          order_id?: string | null
          product_id: string
          rating: number
          status?: Database["public"]["Enums"]["review_status"]
          title?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          is_verified_purchase?: boolean
          moderated_by?: string | null
          order_id?: string | null
          product_id?: string
          rating?: number
          status?: Database["public"]["Enums"]["review_status"]
          title?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_reviews_moderated_by_fkey"
            columns: ["moderated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_reviews_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_reviews_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_reviews_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_reviews_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      product_variants: {
        Row: {
          color: string
          color_hex: string | null
          compare_at_price_paise: number | null
          created_at: string
          id: string
          is_active: boolean
          price_paise: number
          product_id: string
          size: string
          sku: string
          updated_at: string
        }
        Insert: {
          color: string
          color_hex?: string | null
          compare_at_price_paise?: number | null
          created_at?: string
          id?: string
          is_active?: boolean
          price_paise: number
          product_id: string
          size: string
          sku: string
          updated_at?: string
        }
        Update: {
          color?: string
          color_hex?: string | null
          compare_at_price_paise?: number | null
          created_at?: string
          id?: string
          is_active?: boolean
          price_paise?: number
          product_id?: string
          size?: string
          sku?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_variants_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_variants_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          brand_id: string
          care_instructions: string | null
          category_id: string
          created_at: string
          description: string | null
          designer_id: string | null
          details: Json | null
          id: string
          is_launchpad: boolean
          is_made_to_order: boolean
          is_new_arrival: boolean
          materials: string | null
          occasion_id: string | null
          rejection_reason: string | null
          seller_id: string
          slug: string
          status: Database["public"]["Enums"]["product_status"]
          subcategory_id: string
          title: string
          updated_at: string
        }
        Insert: {
          brand_id: string
          care_instructions?: string | null
          category_id: string
          created_at?: string
          description?: string | null
          designer_id?: string | null
          details?: Json | null
          id?: string
          is_launchpad?: boolean
          is_made_to_order?: boolean
          is_new_arrival?: boolean
          materials?: string | null
          occasion_id?: string | null
          rejection_reason?: string | null
          seller_id: string
          slug: string
          status?: Database["public"]["Enums"]["product_status"]
          subcategory_id: string
          title: string
          updated_at?: string
        }
        Update: {
          brand_id?: string
          care_instructions?: string | null
          category_id?: string
          created_at?: string
          description?: string | null
          designer_id?: string | null
          details?: Json | null
          id?: string
          is_launchpad?: boolean
          is_made_to_order?: boolean
          is_new_arrival?: boolean
          materials?: string | null
          occasion_id?: string | null
          rejection_reason?: string | null
          seller_id?: string
          slug?: string
          status?: Database["public"]["Enums"]["product_status"]
          subcategory_id?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_products_brand_seller"
            columns: ["brand_id", "seller_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id", "seller_id"]
          },
          {
            foreignKeyName: "fk_products_category_subcategory"
            columns: ["subcategory_id", "category_id"]
            isOneToOne: false
            referencedRelation: "subcategories"
            referencedColumns: ["id", "category_id"]
          },
          {
            foreignKeyName: "products_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["brand_id"]
          },
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["category_id"]
          },
          {
            foreignKeyName: "products_designer_id_fkey"
            columns: ["designer_id"]
            isOneToOne: false
            referencedRelation: "designers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_designer_id_fkey"
            columns: ["designer_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["designer_id"]
          },
          {
            foreignKeyName: "products_occasion_id_fkey"
            columns: ["occasion_id"]
            isOneToOne: false
            referencedRelation: "occasions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_occasion_id_fkey"
            columns: ["occasion_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["occasion_id"]
          },
          {
            foreignKeyName: "products_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_subcategory_id_fkey"
            columns: ["subcategory_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["subcategory_id"]
          },
          {
            foreignKeyName: "products_subcategory_id_fkey"
            columns: ["subcategory_id"]
            isOneToOne: false
            referencedRelation: "subcategories"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          email: string | null
          full_name: string | null
          id: string
          is_active: boolean
          phone: string | null
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id: string
          is_active?: boolean
          phone?: string | null
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id?: string
          is_active?: boolean
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      refund_transactions: {
        Row: {
          amount_paise: number
          authorized_by: string
          created_at: string
          gateway_refund_id: string | null
          id: string
          order_id: string
          payment_id: string
          reason: string | null
          return_request_id: string | null
          status: Database["public"]["Enums"]["refund_status"]
          updated_at: string
        }
        Insert: {
          amount_paise: number
          authorized_by: string
          created_at?: string
          gateway_refund_id?: string | null
          id?: string
          order_id: string
          payment_id: string
          reason?: string | null
          return_request_id?: string | null
          status?: Database["public"]["Enums"]["refund_status"]
          updated_at?: string
        }
        Update: {
          amount_paise?: number
          authorized_by?: string
          created_at?: string
          gateway_refund_id?: string | null
          id?: string
          order_id?: string
          payment_id?: string
          reason?: string | null
          return_request_id?: string | null
          status?: Database["public"]["Enums"]["refund_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "refund_transactions_authorized_by_fkey"
            columns: ["authorized_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_transactions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_transactions_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payment_transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_transactions_return_request_id_fkey"
            columns: ["return_request_id"]
            isOneToOne: false
            referencedRelation: "return_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      return_requests: {
        Row: {
          created_at: string
          customer_notes: string | null
          id: string
          order_item_id: string
          qc_notes: string | null
          reason: string
          reviewed_by: string | null
          status: Database["public"]["Enums"]["return_request_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          customer_notes?: string | null
          id?: string
          order_item_id: string
          qc_notes?: string | null
          reason: string
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["return_request_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          customer_notes?: string | null
          id?: string
          order_item_id?: string
          qc_notes?: string | null
          reason?: string
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["return_request_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "return_requests_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "return_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "return_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      seller_bank_accounts: {
        Row: {
          account_number: string
          bank_name: string | null
          beneficiary_name: string
          created_at: string
          id: string
          ifsc_code: string
          is_verified: boolean
          penny_drop_status: string
          razorpay_fund_account_id: string | null
          seller_id: string
          updated_at: string
        }
        Insert: {
          account_number: string
          bank_name?: string | null
          beneficiary_name: string
          created_at?: string
          id?: string
          ifsc_code: string
          is_verified?: boolean
          penny_drop_status?: string
          razorpay_fund_account_id?: string | null
          seller_id: string
          updated_at?: string
        }
        Update: {
          account_number?: string
          bank_name?: string | null
          beneficiary_name?: string
          created_at?: string
          id?: string
          ifsc_code?: string
          is_verified?: boolean
          penny_drop_status?: string
          razorpay_fund_account_id?: string | null
          seller_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "seller_bank_accounts_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_bank_accounts_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
        ]
      }
      seller_kyc_documents: {
        Row: {
          created_at: string
          document_type: string
          document_url: string
          id: string
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          seller_id: string
          updated_at: string
          verification_status: Database["public"]["Enums"]["kyc_verification_status"]
        }
        Insert: {
          created_at?: string
          document_type: string
          document_url: string
          id?: string
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          seller_id: string
          updated_at?: string
          verification_status?: Database["public"]["Enums"]["kyc_verification_status"]
        }
        Update: {
          created_at?: string
          document_type?: string
          document_url?: string
          id?: string
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          seller_id?: string
          updated_at?: string
          verification_status?: Database["public"]["Enums"]["kyc_verification_status"]
        }
        Relationships: [
          {
            foreignKeyName: "seller_kyc_documents_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_kyc_documents_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_kyc_documents_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
        ]
      }
      seller_sub_orders: {
        Row: {
          commission_paise: number
          created_at: string
          discount_paise: number
          id: string
          logistics_deduction_paise: number
          net_seller_payable_paise: number
          order_id: string
          seller_id: string
          status: Database["public"]["Enums"]["sub_order_status"]
          sub_order_number: string
          subtotal_paise: number
          tax_paise: number
          tcs_paise: number
          tds_paise: number
          total_amount_paise: number
          updated_at: string
        }
        Insert: {
          commission_paise?: number
          created_at?: string
          discount_paise?: number
          id?: string
          logistics_deduction_paise?: number
          net_seller_payable_paise: number
          order_id: string
          seller_id: string
          status?: Database["public"]["Enums"]["sub_order_status"]
          sub_order_number: string
          subtotal_paise: number
          tax_paise?: number
          tcs_paise?: number
          tds_paise?: number
          total_amount_paise: number
          updated_at?: string
        }
        Update: {
          commission_paise?: number
          created_at?: string
          discount_paise?: number
          id?: string
          logistics_deduction_paise?: number
          net_seller_payable_paise?: number
          order_id?: string
          seller_id?: string
          status?: Database["public"]["Enums"]["sub_order_status"]
          sub_order_number?: string
          subtotal_paise?: number
          tax_paise?: number
          tcs_paise?: number
          tds_paise?: number
          total_amount_paise?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "seller_sub_orders_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_sub_orders_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_sub_orders_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
        ]
      }
      sellers: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          business_name: string
          commission_rate_bps: number | null
          created_at: string
          gstin: string | null
          id: string
          legal_entity_name: string
          pan: string | null
          razorpay_account_id: string | null
          seller_slug: string
          status: Database["public"]["Enums"]["seller_status"]
          suspended_reason: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          business_name: string
          commission_rate_bps?: number | null
          created_at?: string
          gstin?: string | null
          id?: string
          legal_entity_name: string
          pan?: string | null
          razorpay_account_id?: string | null
          seller_slug: string
          status?: Database["public"]["Enums"]["seller_status"]
          suspended_reason?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          business_name?: string
          commission_rate_bps?: number | null
          created_at?: string
          gstin?: string | null
          id?: string
          legal_entity_name?: string
          pan?: string | null
          razorpay_account_id?: string | null
          seller_slug?: string
          status?: Database["public"]["Enums"]["seller_status"]
          suspended_reason?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sellers_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sellers_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      shipments: {
        Row: {
          awb_number: string
          carrier: string
          created_at: string
          delivered_at: string | null
          dispatched_at: string | null
          id: string
          pickup_scheduled_at: string | null
          seller_id: string
          status: Database["public"]["Enums"]["shipment_status"]
          sub_order_id: string
          tracking_url: string | null
          updated_at: string
        }
        Insert: {
          awb_number: string
          carrier: string
          created_at?: string
          delivered_at?: string | null
          dispatched_at?: string | null
          id?: string
          pickup_scheduled_at?: string | null
          seller_id: string
          status?: Database["public"]["Enums"]["shipment_status"]
          sub_order_id: string
          tracking_url?: string | null
          updated_at?: string
        }
        Update: {
          awb_number?: string
          carrier?: string
          created_at?: string
          delivered_at?: string | null
          dispatched_at?: string | null
          id?: string
          pickup_scheduled_at?: string | null
          seller_id?: string
          status?: Database["public"]["Enums"]["shipment_status"]
          sub_order_id?: string
          tracking_url?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipments_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "sellers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_sub_order_id_fkey"
            columns: ["sub_order_id"]
            isOneToOne: false
            referencedRelation: "seller_sub_orders"
            referencedColumns: ["id"]
          },
        ]
      }
      subcategories: {
        Row: {
          category_id: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          slug: string
          sort_order: number
        }
        Insert: {
          category_id: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          slug: string
          sort_order?: number
        }
        Update: {
          category_id?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "subcategories_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subcategories_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "public_catalog_products"
            referencedColumns: ["category_id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["user_role_type"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["user_role_type"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["user_role_type"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      webhook_events: {
        Row: {
          created_at: string
          error_message: string | null
          event_id: string
          event_type: string
          id: number
          payload: Json
          processed: boolean
          processed_at: string | null
          provider: string
          signature: string | null
        }
        Insert: {
          created_at?: string
          error_message?: string | null
          event_id: string
          event_type: string
          id?: number
          payload: Json
          processed?: boolean
          processed_at?: string | null
          provider: string
          signature?: string | null
        }
        Update: {
          created_at?: string
          error_message?: string | null
          event_id?: string
          event_type?: string
          id?: number
          payload?: Json
          processed?: boolean
          processed_at?: string | null
          provider?: string
          signature?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      public_catalog_products: {
        Row: {
          brand_id: string | null
          brand_logo_url: string | null
          brand_name: string | null
          brand_slug: string | null
          care_instructions: string | null
          category_id: string | null
          category_name: string | null
          category_slug: string | null
          created_at: string | null
          description: string | null
          designer_id: string | null
          designer_name: string | null
          designer_slug: string | null
          id: string | null
          is_launchpad: boolean | null
          is_made_to_order: boolean | null
          is_new_arrival: boolean | null
          materials: string | null
          max_price_paise: number | null
          min_price_paise: number | null
          occasion_id: string | null
          occasion_name: string | null
          occasion_slug: string | null
          primary_image_alt: string | null
          primary_image_url: string | null
          slug: string | null
          subcategory_id: string | null
          subcategory_name: string | null
          subcategory_slug: string | null
          title: string | null
        }
        Relationships: []
      }
      public_sellers: {
        Row: {
          business_name: string | null
          id: string | null
          seller_slug: string | null
        }
        Insert: {
          business_name?: string | null
          id?: string | null
          seller_slug?: string | null
        }
        Update: {
          business_name?: string | null
          id?: string | null
          seller_slug?: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      add_to_customer_cart: {
        Args: { p_quantity?: number; p_variant_id: string }
        Returns: string
      }
      apply_as_seller: {
        Args: {
          p_business_name: string
          p_gstin?: string
          p_legal_entity_name: string
          p_pan?: string
          p_seller_slug: string
        }
        Returns: string
      }
      approve_product: { Args: { p_product_id: string }; Returns: Json }
      approve_seller: { Args: { p_seller_id: string }; Returns: boolean }
      can_seller_write_product: {
        Args: { p_product_id: string }
        Returns: boolean
      }
      cancel_checkout_quote: { Args: { p_quote_id: string }; Returns: boolean }
      cancel_order: {
        Args: { p_order_id: string; p_reason?: string }
        Returns: boolean
      }
      clear_customer_cart: { Args: never; Returns: boolean }
      confirm_order_payment: {
        Args: {
          p_gateway_payment_id: string
          p_gateway_signature?: string
          p_order_id: string
        }
        Returns: Json
      }
      consume_inventory_reservation: {
        Args: { p_reservation_id: string }
        Returns: boolean
      }
      consume_quote_reservations: {
        Args: { p_quote_id: string }
        Returns: number
      }
      create_checkout_quote: {
        Args: { p_address_id?: string; p_custom_address?: Json }
        Returns: Json
      }
      create_inventory_reservation: {
        Args: { p_quantity: number; p_quote_id: string; p_variant_id: string }
        Returns: string
      }
      create_order_from_quote: { Args: { p_quote_id: string }; Returns: Json }
      current_seller_id: { Args: never; Returns: string }
      expire_inventory_reservation: {
        Args: { p_reservation_id: string }
        Returns: boolean
      }
      expire_stale_reservations: {
        Args: { p_batch_limit?: number }
        Returns: number
      }
      get_checkout_quote: { Args: { p_quote_id: string }; Returns: Json }
      get_customer_cart: { Args: never; Returns: Json }
      get_customer_wishlist: { Args: never; Returns: Json }
      get_or_create_customer_cart: { Args: never; Returns: string }
      get_order_details: { Args: { p_order_id: string }; Returns: Json }
      get_public_catalog: {
        Args: {
          p_brand_slugs?: string[]
          p_category_slug?: string
          p_is_launchpad?: boolean
          p_is_mto?: boolean
          p_is_new_arrival?: boolean
          p_limit?: number
          p_max_price_paise?: number
          p_min_price_paise?: number
          p_occasion_slugs?: string[]
          p_offset?: number
          p_sort?: string
          p_subcategory_slug?: string
        }
        Returns: Json
      }
      get_public_product_by_slug: { Args: { p_slug: string }; Returns: Json }
      get_variant_available_stock: {
        Args: { p_variant_id: string }
        Returns: number
      }
      has_role: {
        Args: { required_role: Database["public"]["Enums"]["user_role_type"] }
        Returns: boolean
      }
      is_product_visible: { Args: { p_product_id: string }; Returns: boolean }
      is_seller_payout_eligible: {
        Args: { p_seller_id: string }
        Returns: boolean
      }
      is_verified_purchase: { Args: { p_product_id: string }; Returns: boolean }
      merge_guest_cart: { Args: { p_session_id: string }; Returns: boolean }
      product_has_available_inventory: {
        Args: { p_product_id: string }
        Returns: boolean
      }
      reactivate_seller: { Args: { p_seller_id: string }; Returns: boolean }
      record_payment_failure: {
        Args: {
          p_error_code: string
          p_error_description: string
          p_order_id: string
        }
        Returns: Json
      }
      reject_product: {
        Args: { p_product_id: string; p_reason: string }
        Returns: Json
      }
      release_inventory_reservation: {
        Args: { p_reservation_id: string }
        Returns: boolean
      }
      release_quote_reservations: {
        Args: { p_quote_id: string }
        Returns: number
      }
      remove_cart_line: { Args: { p_line_id: string }; Returns: boolean }
      reserve_inventory_for_quote: {
        Args: { p_items: Json; p_quote_id: string }
        Returns: Json
      }
      review_seller_kyc_document: {
        Args: {
          p_document_id: string
          p_rejection_reason?: string
          p_status: Database["public"]["Enums"]["kyc_verification_status"]
        }
        Returns: boolean
      }
      set_default_customer_address: {
        Args: { p_address_id: string }
        Returns: boolean
      }
      set_seller_razorpay_account: {
        Args: { p_razorpay_account_id: string; p_seller_id: string }
        Returns: boolean
      }
      show_limit: { Args: never; Returns: number }
      show_trgm: { Args: { "": string }; Returns: string[] }
      submit_product_for_review: {
        Args: { p_product_id: string }
        Returns: Json
      }
      suspend_seller: {
        Args: { p_reason: string; p_seller_id: string }
        Returns: boolean
      }
      toggle_wishlist_item: { Args: { p_product_id: string }; Returns: boolean }
      update_cart_line_quantity: {
        Args: { p_line_id: string; p_quantity: number }
        Returns: boolean
      }
      verify_seller_bank_account: {
        Args: {
          p_bank_account_id: string
          p_fund_account_id?: string
          p_is_verified: boolean
          p_penny_drop_status: string
        }
        Returns: boolean
      }
    }
    Enums: {
      checkout_quote_status: "pending" | "paid" | "expired" | "cancelled"
      inventory_reservation_status:
        | "held"
        | "committed"
        | "released"
        | "expired"
      kyc_verification_status:
        | "not_submitted"
        | "pending"
        | "verified"
        | "rejected"
      ledger_account_type:
        | "platform_cash_escrow"
        | "customer_payable_refund"
        | "seller_payable_escrow"
        | "statutory_tcs_payable"
        | "statutory_tds_payable"
        | "platform_commission_revenue"
        | "platform_shipping_revenue"
        | "logistics_expense"
      ledger_entry_type: "credit" | "debit"
      media_slot_role: "primary" | "secondary" | "back" | "detail" | "lookbook"
      mto_request_status:
        | "inquiry_submitted"
        | "atelier_review"
        | "price_quoted"
        | "customer_accepted"
        | "advance_paid"
        | "in_crafting"
        | "dispatched"
        | "delivered"
        | "declined"
      notification_channel: "email" | "sms" | "whatsapp"
      notification_status:
        | "queued"
        | "processing"
        | "sent"
        | "failed"
        | "dead_letter"
      order_status:
        | "draft"
        | "placed"
        | "confirmed"
        | "partially_fulfilled"
        | "fulfilled"
        | "completed"
        | "cancelled"
        | "returned"
      payment_transaction_status:
        | "initiated"
        | "pending"
        | "authorized"
        | "captured"
        | "failed"
        | "refunded"
      payout_statement_status:
        | "accruing"
        | "return_hold"
        | "statement_generated"
        | "finance_approved"
        | "settlement_initiated"
        | "settled"
        | "failed"
      product_status:
        | "draft"
        | "submitted"
        | "in_review"
        | "live"
        | "rejected"
        | "suspended"
        | "archived"
      refund_status: "initiated" | "processing" | "completed" | "failed"
      return_request_status:
        | "requested"
        | "support_review"
        | "approved"
        | "pickup_scheduled"
        | "in_transit"
        | "hub_received"
        | "qc_passed"
        | "qc_failed"
        | "refund_authorized"
        | "refunded"
        | "rejected"
      review_status: "pending_moderation" | "published" | "rejected" | "hidden"
      seller_status:
        | "application"
        | "under_review"
        | "approved"
        | "active"
        | "suspended"
        | "terminated"
      shipment_status:
        | "manifest_created"
        | "awb_assigned"
        | "pickup_scheduled"
        | "in_transit"
        | "out_for_delivery"
        | "delivered"
        | "undelivered_attempt"
        | "rto_initiated"
        | "rto_delivered"
      sub_order_status:
        | "pending_acceptance"
        | "accepted"
        | "in_crafting"
        | "packed"
        | "ready_for_pickup"
        | "dispatched"
        | "delivered"
        | "cancelled"
      user_role_type:
        | "customer"
        | "seller"
        | "admin_super"
        | "admin_catalog"
        | "admin_finance"
        | "admin_support"
        | "admin_viewer"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      checkout_quote_status: ["pending", "paid", "expired", "cancelled"],
      inventory_reservation_status: [
        "held",
        "committed",
        "released",
        "expired",
      ],
      kyc_verification_status: [
        "not_submitted",
        "pending",
        "verified",
        "rejected",
      ],
      ledger_account_type: [
        "platform_cash_escrow",
        "customer_payable_refund",
        "seller_payable_escrow",
        "statutory_tcs_payable",
        "statutory_tds_payable",
        "platform_commission_revenue",
        "platform_shipping_revenue",
        "logistics_expense",
      ],
      ledger_entry_type: ["credit", "debit"],
      media_slot_role: ["primary", "secondary", "back", "detail", "lookbook"],
      mto_request_status: [
        "inquiry_submitted",
        "atelier_review",
        "price_quoted",
        "customer_accepted",
        "advance_paid",
        "in_crafting",
        "dispatched",
        "delivered",
        "declined",
      ],
      notification_channel: ["email", "sms", "whatsapp"],
      notification_status: [
        "queued",
        "processing",
        "sent",
        "failed",
        "dead_letter",
      ],
      order_status: [
        "draft",
        "placed",
        "confirmed",
        "partially_fulfilled",
        "fulfilled",
        "completed",
        "cancelled",
        "returned",
      ],
      payment_transaction_status: [
        "initiated",
        "pending",
        "authorized",
        "captured",
        "failed",
        "refunded",
      ],
      payout_statement_status: [
        "accruing",
        "return_hold",
        "statement_generated",
        "finance_approved",
        "settlement_initiated",
        "settled",
        "failed",
      ],
      product_status: [
        "draft",
        "submitted",
        "in_review",
        "live",
        "rejected",
        "suspended",
        "archived",
      ],
      refund_status: ["initiated", "processing", "completed", "failed"],
      return_request_status: [
        "requested",
        "support_review",
        "approved",
        "pickup_scheduled",
        "in_transit",
        "hub_received",
        "qc_passed",
        "qc_failed",
        "refund_authorized",
        "refunded",
        "rejected",
      ],
      review_status: ["pending_moderation", "published", "rejected", "hidden"],
      seller_status: [
        "application",
        "under_review",
        "approved",
        "active",
        "suspended",
        "terminated",
      ],
      shipment_status: [
        "manifest_created",
        "awb_assigned",
        "pickup_scheduled",
        "in_transit",
        "out_for_delivery",
        "delivered",
        "undelivered_attempt",
        "rto_initiated",
        "rto_delivered",
      ],
      sub_order_status: [
        "pending_acceptance",
        "accepted",
        "in_crafting",
        "packed",
        "ready_for_pickup",
        "dispatched",
        "delivered",
        "cancelled",
      ],
      user_role_type: [
        "customer",
        "seller",
        "admin_super",
        "admin_catalog",
        "admin_finance",
        "admin_support",
        "admin_viewer",
      ],
    },
  },
} as const
