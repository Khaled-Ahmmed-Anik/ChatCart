import { useRef, useState } from "react";
import { useIsMutating, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "../../auth/useAuth";
import { apiRequest } from "../../lib/apiClient";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { InboxList } from "../../components/inbox/InboxList";
import { ConversationThread } from "../../components/inbox/ConversationThread";
import { ConversationContext } from "../../components/inbox/ConversationContext";
import { MANAGING_ROLES, needsAttention } from "../../lib/inbox";
import { pollInterval } from "../../lib/polling";

const MOBILE_INBOX_QUERY = "(max-width: 900px)";
const INBOX_ACTION_KEY = ["inbox-action"];

export function ConversationsPage() {
  const { auth } = useAuth();
  const [selectedId, setSelectedId] = useState(null);
  const [drafts, setDrafts] = useState({});
  const [reviewDrafts, setReviewDrafts] = useState({});
  const [failedActions, setFailedActions] = useState({});
  const detailRef = useRef(null);
  const client = useQueryClient();
  const list = useQuery({ queryKey: ["conversations"], queryFn: () => apiRequest("/api/conversations") });
  const detail = useQuery({
    queryKey: ["conversation", selectedId], queryFn: () => apiRequest(`/api/conversations/${selectedId}`),
    enabled: Boolean(selectedId), refetchInterval: selectedId ? pollInterval : false, refetchIntervalInBackground: false
  });
  const action = useMutation({
    mutationKey: INBOX_ACTION_KEY,
    mutationFn: ({ id, path, body }) => apiRequest(`/api/conversations/${id}/${path}`, { method: "POST", body: body ? JSON.stringify(body) : undefined }),
    retry: false,
    onError: (_error, variables) => setFailedActions((current) => ({ ...current, [variables.id]: true })),
    onSuccess: (_result, variables) => {
      setFailedActions((current) => ({ ...current, [variables.id]: false }));
      if (variables.path === "reply") setDrafts((current) => current[variables.id] === variables.draftValue ? { ...current, [variables.id]: "" } : current);
      return Promise.all([
        client.invalidateQueries({ queryKey: ["conversations"] }),
        client.invalidateQueries({ queryKey: ["conversation", variables.id] })
      ]);
    }
  });
  const selected = detail.data;
  const canManage = MANAGING_ROLES.includes(auth.actor?.role);
  const busy = useIsMutating({ mutationKey: INBOX_ACTION_KEY }) > 0;
  const actionError = Boolean(failedActions[selectedId]);
  const actionSuccess = action.isSuccess && action.variables?.id === selectedId ? {
    reply: "Reply saved. Messenger delivery may still be processing.", review: "Review saved.", feedback: "Feedback saved.",
    handover: "Assistant paused for this conversation.", resume: "Conversation handed back to the assistant."
  }[action.variables.path] : null;

  function selectConversation(id) {
    setSelectedId(id);
    if (window.matchMedia(MOBILE_INBOX_QUERY).matches) requestAnimationFrame(() => detailRef.current?.scrollIntoView({ block: "start" }));
  }

  function backToList() {
    setSelectedId(null);
    requestAnimationFrame(() => document.getElementById("inbox-search")?.focus());
  }

  async function refreshConversation() {
    const id = selectedId;
    const result = await detail.refetch();
    if (!result.isError) setFailedActions((current) => ({ ...current, [id]: false }));
  }

  const conversations = list.data || [];
  const attentionCount = conversations.filter(needsAttention).length;

  return <div className="inbox-page">
    <PageHeader title="Inbox" description="Help buyers, follow the conversation, and step in when needed." actions={<span className="home-period">{list.data ? `${attentionCount} ${attentionCount === 1 ? "chat needs" : "chats need"} you` : "Checking Inbox…"}</span>} />
    {list.isPending ? <LoadingState /> : list.isError && !list.data ? <ErrorState error={list.error} onRetry={() => list.refetch()} /> : <>
      {list.isError && <p className="knowledge-notice" role="status">Couldn’t refresh the Inbox. Showing the last loaded conversations. <button className="button secondary small" onClick={() => list.refetch()}>Retry Inbox</button></p>}
      <div className={`inbox-layout ${selectedId ? "has-selection" : ""}`}>
        <InboxList conversations={conversations} selectedId={selectedId} onSelect={selectConversation} />
        <div className="inbox-detail" ref={detailRef}>
          {selectedId ? detail.isPending ? <LoadingState /> : detail.isError && !selected ? <div><button className="button secondary small" onClick={backToList}>← Chats</button><ErrorState error={detail.error} onRetry={() => detail.refetch()} /></div> : selected && <>
            <div className="inbox-thread-area">
              {detail.isError && <p className="knowledge-notice" role="status">Couldn’t refresh this conversation. Actions are disabled until it refreshes.</p>}
              <button className="button secondary small inbox-refresh" onClick={refreshConversation} disabled={detail.isFetching || busy}>Refresh conversation</button>
              <ConversationThread key={selected.id} conversation={selected} canManage={canManage && !detail.isError} draft={drafts[selected.id] || ""}
                onDraft={(value) => setDrafts((current) => ({ ...current, [selected.id]: value }))}
                onReply={() => action.mutate({ id: selected.id, path: "reply", draftValue: drafts[selected.id], body: { content: drafts[selected.id].trim() } })}
                onAction={(path) => action.mutate({ id: selected.id, path })} busy={busy} actionError={actionError} actionSuccess={actionSuccess} onBack={backToList} />
            </div>
            <ConversationContext key={`context-${selected.id}`} conversation={selected} canManage={canManage && !detail.isError} busy={busy || actionError}
              reviewDraft={reviewDrafts[selected.id]} onReviewDraft={(value) => setReviewDrafts((current) => ({ ...current, [selected.id]: value }))}
              onAction={(path, body) => action.mutate({ id: selected.id, path, body })} />
          </> : <EmptyState title="Choose a conversation" description="Select a buyer to view their messages and order details." />}
        </div>
      </div>
    </>}
  </div>;
}
