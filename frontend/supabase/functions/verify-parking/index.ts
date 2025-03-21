import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from '@supabase/supabase-js'

serve(async (req) => {
  const { booking_id, verification_code } = await req.json()
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  try {
    // Verify booking
    const { data, error } = await supabase
      .from('parking_bookings')
      .select('*')
      .eq('id', booking_id)
      .eq('verification_code', verification_code)
      .eq('is_verified', false)
      .single()

    if (error || !data) {
      return new Response(
        JSON.stringify({ success: false, message: 'Invalid verification' }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Update booking status
    await supabase
      .from('parking_bookings')
      .update({ is_verified: true, entry_time: new Date().toISOString() })
      .eq('id', booking_id)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Verification successful',
        command: 'OPEN_GATE'
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, message: error.message }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Add this new endpoint handler
  if (req.url.endsWith('/verify-exit')) {
    // Check for pending payments
    const { data: payment, error: paymentError } = await supabase
      .from('parking_payments')
      .select('*')
      .eq('booking_id', booking_id)
      .eq('status', 'pending')
      .single()

    if (payment) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Payment pending'
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Update exit time
    await supabase
      .from('parking_bookings')
      .update({ 
        exit_time: new Date().toISOString(),
        status: 'completed'
      })
      .eq('id', booking_id)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Exit verified',
        command: 'OPEN_EXIT_GATE'
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  }
}) 