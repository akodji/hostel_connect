// Edge function to send OTP via email
// Save this file as 'send-password-reset-otp.js' in your Supabase project

// Follow the instructions in the Supabase docs to deploy this edge function
// https://supabase.com/docs/guides/functions

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.31.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

export const handler = async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get data from request
    const { email, otp } = await req.json();
    
    if (!email || !otp) {
      return new Response(
        JSON.stringify({ error: 'Email and OTP are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }
    
    // Initialize Supabase client with service role key from environment variables
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    
    // Get user's name from the profiles table
    const { data: profileData, error: profileError } = await supabaseClient
      .from('profiles')
      .select('first_name, last_name')
      .eq('email', email.toLowerCase())
      .single();
      
    if (profileError) {
      console.error('Error fetching profile:', profileError);
    }
    
    const firstName = profileData?.first_name || 'User';
    
    // Format the email
    const subject = 'Password Reset OTP for HostelConnect';
    const htmlContent = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #324054; text-align: center;">Password Reset</h2>
        <p>Hello ${firstName},</p>
        <p>We received a request to reset your password for your HostelConnect account. Please use the following One-Time Password (OTP) to complete the password reset process:</p>
        <div style="background-color: #f5f5f5; padding: 15px; text-align: center; border-radius: 5px; margin: 20px 0;">
          <h1 style="margin: 0; color: #324054; letter-spacing: 5px;">${otp}</h1>
        </div>
        <p>This OTP will expire in 15 minutes.</p>
        <p>If you did not request a password reset, please ignore this email or contact support immediately.</p>
        <p style="margin-top: 30px; font-size: 14px; color: #777;">Regards,<br>The HostelConnect Team</p>
      </div>
    `;
    
    // Send the email
    const { error: emailError } = await supabaseClient.functions.invoke('send-email', {
      body: {
        to: email,
        subject: subject,
        html: htmlContent,
      },
    });
    
    if (emailError) {
      throw emailError;
    }
    
    return new Response(
      JSON.stringify({ success: true, message: 'OTP sent successfully' }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
    
  } catch (error) {
    console.error('Error:', error);
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
};