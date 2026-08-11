"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";

const CANDIDATE_FETCH_LIMIT = 100;
const CANDIDATE_RESULT_LIMIT = 20;
const CANDIDATE_MIN_TEXT_LENGTH = 40;
const CANDIDATE_MIN_RATING = 4;
const CANDIDATE_MAX_AGE_MONTHS = 6;

const SELECT_COLUMNS =
  "feedback_id, profile_id, rating, feedback_text, permission_to_publish, media_url, status, created_at, updated_at, profiles(full_name, email)";

export default function AdminAppFeedbackPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [view, setView] = useState("candidates");
  const [feedbackList, setFeedbackList] = useState([]);

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    // eslint-disable-next-line react-hooks/set-state-in-effect -- synchronous local admin-auth gate check, not fetched data
    setAllowed(true);
  }, [router]);

  useEffect(() => {
    if (!allowed) return;
    fetchFeedback(view);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- fetchFeedback is stable for this component's lifetime
  }, [allowed, view]);

  async function fetchFeedback(currentView) {
    if (currentView === "all") {
      await fetchAllFeedback();
    } else {
      await fetchCandidates();
    }
  }

  async function fetchCandidates() {
    setLoading(true);

    const sinceDate = new Date();
    sinceDate.setMonth(sinceDate.getMonth() - CANDIDATE_MAX_AGE_MONTHS);

    const { data, error } = await supabase
      .from("app_feedback")
      .select(SELECT_COLUMNS)
      .eq("status", "submitted")
      .gte("rating", CANDIDATE_MIN_RATING)
      .eq("permission_to_publish", true)
      .gte("created_at", sinceDate.toISOString())
      .order("rating", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(CANDIDATE_FETCH_LIMIT);

    if (error) {
      console.error("Fetch app feedback candidates error:", error.message);
      setFeedbackList([]);
      setLoading(false);
      return;
    }

    const eligible = (data || []).filter(
      (row) => (row.feedback_text || "").trim().length >= CANDIDATE_MIN_TEXT_LENGTH
    );

    setFeedbackList(formatFeedback(eligible.slice(0, CANDIDATE_RESULT_LIMIT)));
    setLoading(false);
  }

  async function fetchAllFeedback() {
    setLoading(true);

    const { data, error } = await supabase
      .from("app_feedback")
      .select(SELECT_COLUMNS)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Fetch all app feedback error:", error.message);
      setFeedbackList([]);
      setLoading(false);
      return;
    }

    setFeedbackList(formatFeedback(data || []));
    setLoading(false);
  }

  async function updateStatus(row, nextStatus) {
    const { data, error } = await supabase
      .from("app_feedback")
      .update({
        status: nextStatus,
        updated_at: new Date().toISOString(),
      })
      .eq("feedback_id", row.id)
      .select();

    if (error) {
      alert(error.message);
      return;
    }

    if (!data || data.length === 0) {
      alert("Update failed: no rows were changed. This may be blocked by a permissions rule.");
      return;
    }

    await fetchFeedback(view);
  }

  function handleApprove(row) {
    updateStatus(row, "approved");
  }

  function handleReject(row) {
    updateStatus(row, "rejected");
  }

  function handleRemove(row) {
    updateStatus(row, "submitted");
  }

  if (!allowed) {
    return null;
  }

  return (
    <main style={styles.page}>
      <AdminSidebar />

      <section style={styles.content}>
        <div style={styles.tableCard}>
          <div style={styles.topRow}>
            <h2 style={styles.title}>
              App Feedback{" "}
              <span style={styles.count}>
                ({loading ? "..." : formatNumber(feedbackList.length)})
              </span>
            </h2>

            <div style={styles.viewToggle}>
              <button
                type="button"
                onClick={() => setView("candidates")}
                style={{
                  ...styles.toggleButton,
                  ...(view === "candidates" ? styles.toggleButtonActive : {}),
                }}
              >
                Candidates
              </button>

              <button
                type="button"
                onClick={() => setView("all")}
                style={{
                  ...styles.toggleButton,
                  ...(view === "all" ? styles.toggleButtonActive : {}),
                }}
              >
                All feedback
              </button>
            </div>
          </div>

          <div style={styles.tableHeader}>
            <div style={{ ...styles.cell, flex: 1.3 }}>Name</div>
            <div style={{ ...styles.cell, flex: 1.1 }}>Rating</div>
            <div style={{ ...styles.cell, flex: 2 }}>Feedback</div>
            <div style={{ ...styles.cell, flex: 1.05 }}>Submitted</div>
            <div style={{ ...styles.cell, flex: 0.9 }}>Media</div>
            <div style={{ ...styles.cell, flex: 1 }}>Status</div>
            <div style={{ ...styles.cell, flex: 1.7 }}>Actions</div>
          </div>

          {loading ? (
            <div style={styles.emptyMessage}>Loading feedback...</div>
          ) : feedbackList.length > 0 ? (
            feedbackList.map((row) => (
              <div key={row.id} style={styles.tableRow}>
                <div style={{ ...styles.rowCell, flex: 1.3 }}>
                  {row.name}
                </div>

                <div style={{ ...styles.ratingCell, flex: 1.1 }}>
                  <span style={styles.starText}>{renderStars(row.rating)}</span>
                  <span style={styles.ratingText}>
                    ({Number(row.rating || 0)}/5)
                  </span>
                </div>

                <div style={{ ...styles.feedbackCell, flex: 2 }}>
                  {truncateText(row.feedback_text || "-", 60)}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.05 }}>
                  {formatDateTime(row.created_at)}
                </div>

                <div style={{ ...styles.rowCell, flex: 0.9 }}>
                  {row.media_url ? (
                    <a
                      href={row.media_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      style={styles.mediaLink}
                    >
                      View
                    </a>
                  ) : (
                    "-"
                  )}
                </div>

                <div style={{ ...styles.rowCell, flex: 1 }}>
                  {capitalize(row.status)}
                </div>

                <div style={{ ...styles.actionsCell, flex: 1.7 }}>
                  {row.status === "submitted" && (
                    <>
                      <button
                        type="button"
                        onClick={() => handleApprove(row)}
                        style={styles.approveButton}
                      >
                        Approve
                      </button>
                      <button
                        type="button"
                        onClick={() => handleReject(row)}
                        style={styles.rejectButton}
                      >
                        Reject
                      </button>
                    </>
                  )}

                  {row.status === "approved" && (
                    <>
                      <span style={styles.statusApprovedText}>Approved</span>
                      <button
                        type="button"
                        onClick={() => handleRemove(row)}
                        style={styles.removeButton}
                      >
                        Remove
                      </button>
                    </>
                  )}

                  {row.status === "rejected" && (
                    <>
                      <span style={styles.statusRejectedText}>Rejected</span>
                      <button
                        type="button"
                        onClick={() => handleApprove(row)}
                        style={styles.approveButton}
                      >
                        Approve
                      </button>
                    </>
                  )}
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>No feedback found</div>
          )}
        </div>
      </section>
    </main>
  );
}

function formatFeedback(rows) {
  return rows.map((row) => ({
    id: row.feedback_id,
    profile_id: row.profile_id,
    name: row.profiles?.full_name || row.profiles?.email || "-",
    email: row.profiles?.email || "-",
    rating: row.rating,
    feedback_text: row.feedback_text,
    permission_to_publish: row.permission_to_publish,
    media_url: row.media_url,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
  }));
}

function renderStars(rating) {
  const number = Number(rating || 0);
  const filledStars = "★".repeat(number);
  const emptyStars = "☆".repeat(5 - number);

  return filledStars + emptyStars;
}

function capitalize(value) {
  if (!value) return "-";
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function truncateText(text, maxLength) {
  if (!text) return "-";

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength)}...`;
}

function formatDateTime(value) {
  if (!value) return "-";

  const date = new Date(value);

  return date.toLocaleString("en-US", {
    month: "numeric",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function formatNumber(value) {
  return Number(value).toLocaleString();
}

const styles = {
  page: {
    minHeight: "100vh",
    display: "flex",
    backgroundColor: "#f8f8ff",
    fontFamily: "Arial, sans-serif",
    color: "#000000",
    position: "relative",
  },

  content: {
    flex: 1,
    padding: "82px 58px",
    boxSizing: "border-box",
  },

  tableCard: {
    backgroundColor: "#ffffff",
    borderRadius: "26px",
    padding: "44px 30px 10px",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
    minHeight: "calc(100vh - 164px)",
    boxSizing: "border-box",
  },

  topRow: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "34px",
    gap: "18px",
  },

  title: {
    fontSize: "21px",
    fontWeight: "700",
    margin: 0,
    whiteSpace: "nowrap",
  },

  count: {
    color: "#9b9b9b",
    fontWeight: "500",
  },

  viewToggle: {
    display: "flex",
    alignItems: "center",
    gap: "10px",
    backgroundColor: "#f3f3fa",
    borderRadius: "10px",
    padding: "4px",
  },

  toggleButton: {
    height: "34px",
    borderRadius: "8px",
    border: "none",
    padding: "0 16px",
    fontSize: "13px",
    fontWeight: "600",
    backgroundColor: "transparent",
    color: "#777777",
    cursor: "pointer",
  },

  toggleButtonActive: {
    backgroundColor: "#ffffff",
    color: "#6658ff",
    boxShadow: "0 2px 6px rgba(0, 0, 0, 0.08)",
  },

  tableHeader: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #dddddd",
    padding: "18px 10px",
    color: "#8e8e8e",
    fontSize: "13px",
  },

  tableRow: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #e5e5e5",
    padding: "14px 10px",
    minHeight: "66px",
    boxSizing: "border-box",
  },

  cell: {
    fontWeight: "500",
  },

  rowCell: {
    fontSize: "13px",
    display: "flex",
    alignItems: "center",
  },

  ratingCell: {
    fontSize: "13px",
    display: "flex",
    flexDirection: "column",
    alignItems: "flex-start",
    gap: "3px",
  },

  feedbackCell: {
    fontSize: "13px",
    color: "#777777",
    lineHeight: "16px",
  },

  starText: {
    color: "#f5b800",
    letterSpacing: "1px",
  },

  ratingText: {
    color: "#888888",
    fontSize: "12px",
  },

  mediaLink: {
    fontSize: "12px",
    fontWeight: "700",
    color: "#6658ff",
    textDecoration: "none",
  },

  actionsCell: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
    flexWrap: "wrap",
  },

  approveButton: {
    height: "30px",
    borderRadius: "7px",
    border: "1px solid #4caf50",
    backgroundColor: "#ffffff",
    color: "#4caf50",
    fontSize: "12px",
    fontWeight: "700",
    padding: "0 12px",
    cursor: "pointer",
  },

  rejectButton: {
    height: "30px",
    borderRadius: "7px",
    border: "1px solid #ef4444",
    backgroundColor: "#ffffff",
    color: "#ef4444",
    fontSize: "12px",
    fontWeight: "700",
    padding: "0 12px",
    cursor: "pointer",
  },

  removeButton: {
    height: "30px",
    borderRadius: "7px",
    border: "1px solid #cfcfcf",
    backgroundColor: "#ffffff",
    color: "#777777",
    fontSize: "12px",
    fontWeight: "700",
    padding: "0 12px",
    cursor: "pointer",
  },

  statusApprovedText: {
    fontSize: "12px",
    fontWeight: "700",
    color: "#4caf50",
  },

  statusRejectedText: {
    fontSize: "12px",
    fontWeight: "700",
    color: "#ef4444",
  },

  emptyMessage: {
    padding: "36px 10px",
    textAlign: "center",
    color: "#888888",
    fontSize: "16px",
  },
};
