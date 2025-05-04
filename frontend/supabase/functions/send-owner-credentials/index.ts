// Follow this setup guide to integrate the Deno runtime into your application:
// https://docs.supabase.com/guides/functions/deploy-supabase-edge-functions

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'
import { corsHeaders } from '../_shared/cors.ts'
import { EmailClient } from "https://deno.land/x/sendgrid@0.0.1/mod.ts";

interface CredentialsRequest {
  email: string
  password: string
  ownerName: string
  parkingLotName: string
}

serve(async (req) => {
  // This is needed if you're planning to invoke your function from a browser.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, password, ownerName, parkingLotName } = await req.json() as CredentialsRequest

    // Create a Supabase client with the Auth context of the logged in user
    const supabaseClient = createClient(
      // Supabase API URL - env var exposed by default when deployed
      Deno.env.get('SUPABASE_URL') ?? '',
      // Supabase API ANON KEY - env var exposed by default when deployed
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      // Create client with Auth context of the user that called the function.
      // This way your row-level-security (RLS) policies are applied.
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get SendGrid API key from Supabase env vars
    const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY') ?? ''
    
    if (!SENDGRID_API_KEY) {
      throw new Error('Missing SendGrid API key')
    }

    // Initialize SendGrid client
    const sendgrid = new EmailClient({
      apiKey: SENDGRID_API_KEY,
    });

    // Set the from email address (must be verified in SendGrid)
    const from = Deno.env.get('EMAIL_FROM') ?? 'noreply@smartpark.app'
    
    // HTML email template
    const emailHtml = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          color: #333;
          line-height: 1.6;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          border: 1px solid #ddd;
          border-radius: 5px;
        }
        .header {
          background-color: #1A73E8;
          color: white;
          padding: 15px;
          text-align: center;
          border-radius: 5px 5px 0 0;
        }
        .content {
          padding: 20px;
          background-color: #f9f9f9;
        }
        .credentials {
          margin: 20px 0;
          padding: 15px;
          background-color: #f0f0f0;
          border-left: 4px solid #1A73E8;
        }
        .footer {
          text-align: center;
          color: #666;
          font-size: 12px;
          margin-top: 20px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Smart Park Login Credentials</h1>
        </div>
        <div class="content">
          <p>Hello ${ownerName},</p>
          <p>Your parking lot "${parkingLotName}" has been successfully registered with Smart Park. You can now use the following credentials to log in and manage your parking lot:</p>
          
          <div class="credentials">
            <p><strong>Email:</strong> ${email}</p>
            <p><strong>Password:</strong> ${password}</p>
          </div>
          
          <p>Once logged in, you will be able to:</p>
          <ul>
            <li>Monitor active bookings at your parking lot</li>
            <li>View parking analytics and revenue stats</li>
            <li>Manage parking slots</li>
            <li>Mark vehicle entries and exits</li>
          </ul>
          
          <p>For security reasons, we recommend changing your password after your first login.</p>
          
          <p>If you have any questions or need assistance, please contact our support team.</p>
          
          <p>Best regards,<br>
          The Smart Park Team</p>
        </div>
        <div class="footer">
          <p>© ${new Date().getFullYear()} Smart Park. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    `

    // Send the email
    await sendgrid.send({
      to: email,
      from: {
        email: from,
        name: 'Smart Park',
      },
      subject: `Your Smart Park Login Credentials for ${parkingLotName}`,
      html: emailHtml,
    });

    // Return a success response
    return new Response(
      JSON.stringify({ 
        success: true,
        message: 'Credentials email sent successfully' 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false,
        error: error.message 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
}) 