// Edge function to delete a user account
// Save this as delete-user-account.js in your Supabase Edge Functions

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// This is a Deno server function that will be executed in Supabase's infrastructure
Deno.serve(async (req) => {
  try {
    // Get the request data
    const { user_id, email } = await req.json()
    
    if (!user_id || !email) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: "Missing required parameters" 
        }),
        { 
          status: 400,
          headers: { "Content-Type": "application/json" }
        }
      )
    }
    
    // Initialize Supabase admin client with service role key
    // IMPORTANT: This uses the service_role key which has admin privileges
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )
    
    // Delete related data first if necessary
    // Example: update bookings to soft-delete
    await supabaseAdmin
      .from('bookings')
      .update({
        'status': 'cancelled',
        'is_deleted': true,
        'updated_at': new Date().toISOString()
      })
      .eq('user_id', user_id)
    
    // Delete the user from auth.users using admin API
    // This is the critical part for deleting from auth.users table
    const { error } = await supabaseAdmin.auth.admin.deleteUser(user_id)
    
    if (error) {
      console.error("Error deleting user:", error.message)
      
      // If the admin API fails, try using raw SQL as a last resort
      // This requires special permissions and should be carefully implemented
      try {
        // Using RPC to call our custom SQL function for deletion
        const { data, error: rpcError } = await supabaseAdmin.rpc(
          'delete_user_account',
          { user_id }
        )
        
        if (rpcError) {
          console.error("RPC deletion error:", rpcError.message)
          throw rpcError
        }
        
        return new Response(
          JSON.stringify({ success: true, message: "User deleted via RPC" }),
          { 
            status: 200,
            headers: { "Content-Type": "application/json" }
          }
        )
      } catch (sqlError) {
        console.error("SQL deletion error:", sqlError.message)
        throw error
      }
    }
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "User successfully deleted" 
      }),
      { 
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    )
  }
})