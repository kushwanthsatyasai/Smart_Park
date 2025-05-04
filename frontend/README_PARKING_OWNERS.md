# Parking Lot Owner Feature - Smart Park

This document provides information on the new parking lot owner functionality added to the Smart Park application.

## Overview

The parking lot owner feature allows for:

1. Admins to register new parking lots with dedicated owner accounts
2. Parking lot owners to login and manage their lots
3. Owners to view bookings and analytics for their specific lots
4. Mark vehicle entries and exits
5. Automatic email notification of credentials to new owners

## Database Changes

Before using this feature, you need to apply the database schema changes:

1. Navigate to the Supabase dashboard for your project
2. Go to the SQL Editor
3. Copy and paste the contents of `supabase/parking_owner_schema.sql`
4. Run the SQL commands to update your schema

## Email Notification Setup

The system can automatically send login credentials to new parking lot owners via email. To enable this:

1. Create a SendGrid account and obtain an API key
2. Deploy the Supabase Edge Function for sending emails:
   ```bash
   supabase functions deploy send-owner-credentials --no-verify-jwt
   ```
3. Set the required environment variables in the Supabase dashboard:
   - Go to Settings > API > Functions
   - Add the following secrets:
     - `SENDGRID_API_KEY`: Your SendGrid API key
     - `EMAIL_FROM`: The verified sender email (e.g., noreply@yourdomain.com)

## Features

### For Admins:

- **Enhanced Parking Lot Registration**: Creates both a parking lot and an owner account simultaneously
- **Owner Credential Management**: Generates secure passwords for parking owners
- **Detailed Parking Information**: Collects coordinates, address, and slot details
- **Rate Setting**: Set the parking lot's global price per hour
- **Email Notifications**: Automatically send login credentials to owners

### For Parking Lot Owners:

- **Dedicated Dashboard**: View only their parking lots
- **Active Booking Management**: Mark vehicle exits
- **Analytics Overview**: View revenue and booking statistics
- **Slot Management**: Add and edit parking slots for their lots

## Implementation Notes

1. The application automatically detects user roles and directs them to the appropriate dashboard
2. Row-Level Security policies ensure that owners can only access their own data
3. New `parking_owner` role has been added to the user roles
4. Email notifications are optional and can be toggled during registration

## How to Test

1. Login as an admin
2. Navigate to "Register Parking Lot" in the sidebar
3. Complete the form with owner details and lot information
4. Choose whether to send an email notification
5. Save the generated owner credentials
6. Logout and login with the new owner credentials
7. Explore the owner dashboard features

## Database Schema

The following tables have been updated:

- `profiles`: Added `parking_owner` role
- `parking_lots`: Added location details, vehicle type flags, and slot counts
- `parking_slots`: No structural changes, but added RLS policies

## Security Considerations

- RLS policies ensure data separation between different owners
- Parking lot owners cannot modify bookings for lots they don't own
- Owner role is distinct from admin role with limited permissions 