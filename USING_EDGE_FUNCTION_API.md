# Using the ticket-card-api Edge Function in Your iOS App

This guide explains how to use the `ticket-card-api` Edge Function that's deployed on your Supabase project.

## What's Been Added

### 1. TicketAPIService.swift
A new service class that provides methods to interact with your `ticket-card-api` Edge Function:

**Methods Available:**
- `getTickets()` - Fetch all tickets
- `createTicket(...)` - Create a new ticket
- `updateTicket(...)` - Update an existing ticket
- `deleteTicket(ticketId:)` - Delete a ticket

### 2. HomeView Integration
The HomeView now has the ability to load tickets from the Edge Function API instead of direct database queries.

## How to Use It

### Option 1: Use Edge Function API (Recommended if API is deployed)

In `HomeView.swift`, change this line:

```swift
private let useEdgeFunction = false
```

To:

```swift
private let useEdgeFunction = true
```

This will make the app use the Edge Function API to load tickets instead of direct database queries.

### Option 2: Continue Using Direct Database Calls (Current Default)

Leave the setting as:

```swift
private let useEdgeFunction = false
```

The app will continue using direct Supabase database queries.

## API Endpoints

The Edge Function is available at:
```
https://yefflsjyohrspybflals.supabase.co/functions/v1/ticket-card-api
```

### GET / - Get All Tickets
**Request:**
```http
GET /ticket-card-api
Authorization: Bearer YOUR_JWT_TOKEN
```

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Event Title",
      "organizer_id": "uuid",
      "organizer_username": "username",
      "event_date": "2025-01-01T00:00:00Z",
      "last_entry": "2025-01-01T00:00:00Z",
      "price": 50.00,
      "available_tickets": 2,
      "age_restriction": 18,
      "ticket_source": "Fatsoma",
      "ticket_image_url": "https://...",
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```

### POST / - Create Ticket
**Request:**
```http
POST /ticket-card-api
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "title": "Event Title",
  "event_date": "2025-01-01T00:00:00Z",
  "last_entry": "2025-01-01T00:00:00Z",
  "price": 50.00,
  "available_tickets": 2,
  "age_restriction": 18,
  "ticket_source": "Fatsoma",
  "ticket_image_url": "https://...",
  "city": "London"
}
```

### PUT /:id - Update Ticket
**Request:**
```http
PUT /ticket-card-api/TICKET_UUID
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "price": 45.00,
  "available_tickets": 1
}
```

### DELETE /:id - Delete Ticket
**Request:**
```http
DELETE /ticket-card-api/TICKET_UUID
Authorization: Bearer YOUR_JWT_TOKEN
```

## Example Usage in Your App

### Fetching Tickets

```swift
let ticketAPI = TicketAPIService()

// Get all tickets
do {
    let tickets = try await ticketAPI.getTickets()
    print("Loaded \(tickets.count) tickets")
} catch {
    print("Error: \(error)")
}
```

### Creating a Ticket

```swift
let ticketAPI = TicketAPIService()

do {
    let newTicket = try await ticketAPI.createTicket(
        title: "Summer Festival",
        eventDate: Date(),
        lastEntry: Date(),
        price: 50.0,
        availableTickets: 2,
        ageRestriction: 18,
        ticketSource: "Fatsoma",
        ticketImageUrl: "https://example.com/image.jpg",
        city: "London"
    )
    print("Created ticket: \(newTicket.title)")
} catch {
    print("Error: \(error)")
}
```

### Updating a Ticket

```swift
let ticketAPI = TicketAPIService()

do {
    let updated = try await ticketAPI.updateTicket(
        ticketId: ticketUUID,
        title: nil,  // Don't update title
        eventDate: nil,
        lastEntry: nil,
        price: 45.0,  // Update price
        availableTickets: 1,  // Update available tickets
        ageRestriction: nil,
        ticketSource: nil,
        ticketImageUrl: nil,
        city: nil
    )
    print("Updated ticket")
} catch {
    print("Error: \(error)")
}
```

### Deleting a Ticket

```swift
let ticketAPI = TicketAPIService()

do {
    try await ticketAPI.deleteTicket(ticketId: ticketUUID)
    print("Deleted ticket")
} catch {
    print("Error: \(error)")
}
```

## Benefits of Using Edge Function API

### Advantages:
1. **Business Logic on Server** - Complex logic stays on the server
2. **Security** - Can use service role key without exposing it
3. **Flexibility** - Easy to add custom logic (validation, notifications, etc.)
4. **Centralized** - One API for multiple platforms (iOS, Android, Web)
5. **Rate Limiting** - Can implement rate limiting on the server

### Disadvantages:
1. **Extra Network Hop** - Slightly slower than direct database access
2. **Cold Starts** - Edge Functions may have slight delay when idle
3. **Debugging** - More complex to debug than direct queries

## When to Use Which?

### Use Edge Function API when:
- You need complex business logic
- You're building multiple clients (iOS + Web)
- You need server-side validation
- You want to hide database structure from clients

### Use Direct Database when:
- You want fastest performance
- Your app is simple with straightforward queries
- You're only building one client (iOS)
- You trust client-side validation

## Current Setup

**Default:** Uses **direct database queries** (faster, simpler)

**To enable Edge Function API:** Change `useEdgeFunction = true` in HomeView.swift

## Troubleshooting

### Error: "Invalid response from server"
- Check that the Edge Function is deployed
- Verify the URL is correct
- Check network connection

### Error: "HTTP error: 401"
- User is not authenticated
- JWT token is invalid or expired
- Try logging out and back in

### Error: "HTTP error: 500"
- Server error in Edge Function
- Check Edge Function logs in Supabase Dashboard

### Tickets not loading
- Check console for error messages
- Verify `useEdgeFunction` is set correctly
- Try switching back to direct database temporarily

## Next Steps

1. **Test the API** - Try switching to Edge Function mode
2. **Monitor Performance** - Compare speed of both methods
3. **Add Features** - Extend the API with more endpoints
4. **Implement Caching** - Add local caching for better performance

## Need Help?

- Check Edge Function logs in Supabase Dashboard
- Review the `TicketAPIService.swift` code
- Test API endpoints using curl or Postman
- Refer to Supabase Edge Functions documentation
