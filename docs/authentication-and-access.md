# Authentication and access lifecycle

ChatCart uses password authentication for platform administrators and business users. A successful login returns an opaque bearer token backed by an `AuthSession` record. Only the token digest is stored, and sessions expire after 12 hours.

## Login rules

A platform administrator can sign in only while their account is active. A business user can sign in only when both the user account and its business are active.

API requests are rejected with `401 Unauthorized` when the token is missing, expired, revoked, belongs to an inactive account, or belongs to an inactive business. Reactivating an account or business never restores an old session; the user must sign in again.

## Session revocation

Normal sign-out ends only the current session. There is intentionally no user-facing “sign out every device” action in the MVP.

Administrative safety actions revoke all affected active sessions immediately:

- Disabling a user revokes every session belonging to that user.
- Suspending or disabling a business revokes every session belonging to every user in that business.
- Revocation is performed in the same database transaction as the status change.
- Other users and other businesses are unaffected.

Session records retain a safe revocation reason for auditing. Raw bearer tokens, passwords, Meta access tokens, and application secrets must never be logged.

## Business lifecycle

| Status | Dashboard login | Messaging automation | Existing data |
| --- | --- | --- | --- |
| `active` | Allowed for active users | Enabled | Retained |
| `suspended` | Blocked | Stopped | Retained |
| `disabled` | Blocked | Stopped | Retained |

Suspension is suitable for a temporary operational pause. Disabled is suitable when the business should no longer use ChatCart. Both statuses enforce the same access boundary; retaining separate statuses lets administrators communicate intent and report on lifecycle state.

When a business is not active:

- Messenger and WhatsApp message events are acknowledged but not queued for processing.
- Already queued inbound events are marked ignored.
- Queued outbound Messenger and WhatsApp deliveries are skipped.
- Queued delivery-provider submissions are skipped.

Acknowledging channel webhooks prevents Meta from retrying valid events indefinitely while the business is paused.

## Administration

Only a platform administrator can change a business lifecycle status. In the platform dashboard, open **Businesses** and choose **Suspend**, **Disable**, or **Reactivate**. The confirmation dialog describes the access and messaging impact before the update is sent.

Business owners and staff cannot change their own business status. The status update endpoint validates supported values and returns `422 Unprocessable Entity` for an invalid status.

## Operational checks

After suspending or disabling a business, verify:

1. Existing business-user bearer tokens receive `401 Unauthorized`.
2. New login attempts for that business receive `401 Unauthorized`.
3. New channel messages do not create processing jobs or replies.
4. Other businesses continue to authenticate and process messages.

After reactivation, verify that a fresh login succeeds and that a previously issued token remains invalid.
