# PRD: Simple Todo API

## Overview
Build a RESTful API for managing todo items with basic CRUD operations.

## Goals
- Create a working API that can be tested with curl/Postman
- Use JSON for data exchange
- Include basic error handling
- Add simple persistence (file-based or in-memory)

## Technical Requirements
- **Language**: Python (Flask) or Node.js (Express)
- **Storage**: JSON file or in-memory array
- **Testing**: Should be manually testable via curl

## Features

### MVP (Phase 1)
1. **GET /todos** - List all todos
2. **POST /todos** - Create a new todo
3. **GET /todos/:id** - Get a specific todo
4. **PUT /todos/:id** - Update a todo
5. **DELETE /todos/:id** - Delete a todo

### Data Model
```json
{
  "id": "unique-id",
  "title": "Todo title",
  "completed": false,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

## Acceptance Criteria

### For Each Endpoint:
- Returns appropriate HTTP status codes (200, 201, 404, 400, 500)
- Returns JSON responses
- Handles errors gracefully
- Can be tested with curl

### Overall:
- Server starts without errors
- Data persists between requests (if using file storage)
- Basic validation (e.g., title is required)
- README with usage examples

## Out of Scope (Future)
- Authentication
- Database integration
- Pagination
- Filtering/sorting
- Rate limiting

## Example Usage
```bash
# Create a todo
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy groceries"}'

# List todos
curl http://localhost:3000/todos

# Update a todo
curl -X PUT http://localhost:3000/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'

# Delete a todo
curl -X DELETE http://localhost:3000/todos/1
```

## Success Metrics
- All 5 endpoints work correctly
- Returns proper status codes
- Data persists (if file-based)
- Can complete full CRUD cycle via curl
