# Product Roadmap (Epics Breakdown)

## Phase 0 — Foundation

### EPIC 0.1 — Project Infrastructure

* Rails app setup
* PostgreSQL & Redis setup
* RSpec, FactoryBot, RuboCop

### EPIC 0.2 — Domain Model

* Hotel
* Guest
* Staff
* Department
* Conversation
* Message
* Ticket
* KnowledgeBaseArticle

### EPIC 0.3 — Access Control & Admin

* Roles: admin, manager, staff
* Admin panel
* Authorization rules

### EPIC 0.4 — Project Governance

* PROJECT.md
* AGENTS.md

---

## Phase 1 — Core Domain & Admin

### EPIC 1.1 — Hotel Management

* CRUD hotels

### EPIC 1.2 — Staff & Departments

* CRUD staff
* CRUD departments

### EPIC 1.3 — Ticket Management Core

* CRUD tickets
* Statuses (new, in_progress, done, canceled)
* Priorities (low, medium, high) 
* Assignment
* History

### EPIC 1.4 — Knowledge Base Management

* CRUD articles

### EPIC 1.5 — Messaging Backoffice

* Conversations list
* Messages list

---

## Phase 2 — Guest Communication MVP

### EPIC 2.1 — Guest Identity & Access

* QR / magic link / room+name
* Session handling

### EPIC 2.2 — Conversation Lifecycle

* Create conversation
* Statuses (open, waiting_for_staff, waiting_for_guest, closed)

### EPIC 2.3 — Messaging System

* Send message
* Store message
* Staff reply UI

### EPIC 2.4 — Chat UX Strategy

* Channel model
* Entry UX

---

## Phase 3 — Knowledge Base & AI

### EPIC 3.1 — Knowledge Base Structure

* title, category, content, tags, locale, published

### EPIC 3.2 — Retrieval System

* Search
* Ranking

### EPIC 3.3 — AI Response Engine

* AI answers
* Confidence threshold
* Escalation

### EPIC 3.4 — Feedback Loop

* helpful / incorrect / escalate
* Logging

---

## Phase 4 — Ticket Automation

### EPIC 4.1 — Ticket Creation from Chat

* Create ticket from message
* Link ticket ↔ conversation

### EPIC 4.2 — Ticket Classification

* Categories
* Auto classification

### EPIC 4.3 — Assignment Engine

* Category → department
* Staff assignment

### EPIC 4.4 — SLA Tracking

* created_at
* first_response_at
* resolved_at

### EPIC 4.5 — Notifications

* New ticket alerts
* Status updates

---

## Phase 5 — Staff Workflow Optimization

### EPIC 5.1 — Queues & Filters

* Department queues
* Filters

### EPIC 5.2 — Internal Collaboration

* Notes
* Mentions

### EPIC 5.3 — Bulk Operations

* Bulk status update
* Bulk assignment

### EPIC 5.4 — Dashboard

* Needs attention
* SLA alerts

### EPIC 5.5 — Response Templates

* Templates
* Quick insert

### EPIC 5.6 — Audit Log

* Action history

---

## Phase 6 — Analytics

### EPIC 6.1 — Metrics Collection

* Events tracking

### EPIC 6.2 — Metrics Aggregation

* Aggregations

### EPIC 6.3 — Reporting

* Daily / weekly / monthly
* Per hotel

### EPIC 6.4 — Operational Insights

* Top questions
* Bottlenecks

---

## Phase 7 — Multi-language Support

### EPIC 7.1 — Localization Infrastructure

* Locale support
* Fallback

### EPIC 7.2 — Multilingual Knowledge Base

* Translations

### EPIC 7.3 — Language Detection

* Detect guest language

### EPIC 7.4 — AI Localization

* Localized responses

### EPIC 7.5 — Staff UI Localization

* UI language

---

## Phase 8 — Multi-tenant Architecture

### EPIC 8.1 — Tenant Isolation

* hotel_id scoping

### EPIC 8.2 — Access Control per Tenant

* Scoped users

### EPIC 8.3 — Config per Hotel

* Departments
* Categories
* Templates

### EPIC 8.4 — Data Segregation

* Isolation guarantees

### EPIC 8.5 — Tenant Provisioning

* Create hotel

---

## Phase 9 — Integrations

### EPIC 9.1 — Messaging Channels

* Web widget
* WhatsApp
* Telegram

### EPIC 9.2 — PMS Integration

* Guest sync

### EPIC 9.3 — Notification Integrations

* Email
* SMS
* Push

### EPIC 9.4 — Webhooks

* External events

### EPIC 9.5 — Integration Framework

* Retry logic
* Error handling

---

## Cross-cutting Epics

### EPIC X.1 — AI Infrastructure

* Prompt management
* Model configs
* Cost tracking

### EPIC X.2 — Observability

* Logging
* Error tracking
* Tracing

### EPIC X.3 — Permissions System

* RBAC
* Policies
