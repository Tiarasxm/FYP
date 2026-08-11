"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";

export default function AdminReviewsPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);

  const [reviews, setReviews] = useState([]);
  const [tierFilter, setTierFilter] = useState("All Tier");
  const [ratingFilter, setRatingFilter] = useState("All Rating");
  const [sortFilter, setSortFilter] = useState("Latest");
  const [mediaFilter, setMediaFilter] = useState("All Media");
  const [analysisFilter, setAnalysisFilter] = useState("All Analysis");
  const [searchKeyword, setSearchKeyword] = useState("");

  const [selectedReview, setSelectedReview] = useState(null);

  async function fetchReviews() {
    setLoading(true);

    const { data, error } = await supabase
      .from("reviews")
      .select(
        "review_id, reviewer_id, rating, feedback, media_path, ai_analysis, submitted_at, profiles!reviews_reviewer_id_fkey(full_name, email, user_type)"
      )
      .order("submitted_at", { ascending: false });

    if (error) {
      console.error("Fetch reviews error:", error.message);
      setReviews([]);
      setLoading(false);
      return;
    }

    const formattedReviews = (data || []).map((review) => ({
      id: review.review_id,
      reviewer_id: review.reviewer_id,
      reviewer_name: review.profiles?.full_name || "-",
      reviewer_email: review.profiles?.email || "-",
      tier: review.profiles?.user_type || "-",
      rating: review.rating,
      feedback: review.feedback,
      media_path: review.media_path,
      ai_analysis: review.ai_analysis,
      submitted_at: review.submitted_at,
    }));

    setReviews(formattedReviews);
    setLoading(false);
  }

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    // eslint-disable-next-line react-hooks/set-state-in-effect -- synchronous local admin-auth gate check, not fetched data
    setAllowed(true);
    fetchReviews();
  }, [router]);

  function handleViewMedia(review) {
    if (!review.media_path) {
      alert("No media uploaded.");
      return;
    }

    const { data } = supabase.storage
      .from("review-media")
      .getPublicUrl(review.media_path);

    if (!data?.publicUrl) {
      alert("Unable to open media.");
      return;
    }

    window.open(data.publicUrl, "_blank", "noopener,noreferrer");
  }

  const filteredReviews = useMemo(() => {
    let result = [...reviews];

    if (tierFilter !== "All Tier") {
      result = result.filter((review) => review.tier === tierFilter);
    }

    if (ratingFilter !== "All Rating") {
      const ratingNumber = Number(ratingFilter.replace(" Stars", ""));
      result = result.filter((review) => Number(review.rating) === ratingNumber);
    }

    if (mediaFilter === "With Media") {
      result = result.filter((review) => review.media_path);
    }

    if (mediaFilter === "Without Media") {
      result = result.filter((review) => !review.media_path);
    }

    if (analysisFilter !== "All Analysis") {
      result = result.filter(
        (review) =>
          normalizeAnalysis(review.ai_analysis) === analysisFilter
      );
    }

    const keyword = searchKeyword.trim().toLowerCase();

    if (keyword) {
      result = result.filter((review) => {
        return (
          review.id?.toLowerCase().includes(keyword) ||
          review.reviewer_name?.toLowerCase().includes(keyword) ||
          review.reviewer_email?.toLowerCase().includes(keyword) ||
          review.tier?.toLowerCase().includes(keyword) ||
          review.feedback?.toLowerCase().includes(keyword)
        );
      });
    }

    result.sort((a, b) => {
      const dateA = new Date(a.submitted_at || 0).getTime();
      const dateB = new Date(b.submitted_at || 0).getTime();

      return sortFilter === "Latest" ? dateB - dateA : dateA - dateB;
    });

    return result;
  }, [
    reviews,
    tierFilter,
    ratingFilter,
    sortFilter,
    mediaFilter,
    analysisFilter,
    searchKeyword,
  ]);

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
              Reviews{" "}
              <span style={styles.count}>
                ({loading ? "..." : formatNumber(reviews.length)})
              </span>
            </h2>

            <div style={styles.filters}>
              <select
                style={styles.select}
                value={tierFilter}
                onChange={(event) => setTierFilter(event.target.value)}
              >
                <option>All Tier</option>
                <option>Free</option>
                <option>Priority</option>
              </select>

              <select
                style={styles.select}
                value={ratingFilter}
                onChange={(event) => setRatingFilter(event.target.value)}
              >
                <option>All Rating</option>
                <option>5 Stars</option>
                <option>4 Stars</option>
                <option>3 Stars</option>
                <option>2 Stars</option>
                <option>1 Stars</option>
                <option>0 Stars</option>
              </select>

              <select
                style={styles.select}
                value={sortFilter}
                onChange={(event) => setSortFilter(event.target.value)}
              >
                <option>Latest</option>
                <option>Oldest</option>
              </select>

              <select
                style={styles.select}
                value={mediaFilter}
                onChange={(event) => setMediaFilter(event.target.value)}
              >
                <option>All Media</option>
                <option>With Media</option>
                <option>Without Media</option>
              </select>

              <select
                style={styles.select}
                value={analysisFilter}
                onChange={(event) => setAnalysisFilter(event.target.value)}
              >
                <option>All Analysis</option>
                <option>Positive</option>
                <option>Negative</option>
                <option>Neutral</option>
              </select>

              <div style={styles.searchBox}>
                <SearchIcon />

                <input
                  type="text"
                  placeholder="Search"
                  value={searchKeyword}
                  onChange={(event) => setSearchKeyword(event.target.value)}
                  style={styles.searchInput}
                />
              </div>
            </div>
          </div>

          <div style={styles.tableHeader}>
            <div style={{ ...styles.cell, flex: 0.9 }}>Review ID</div>
            <div style={{ ...styles.cell, flex: 1.35 }}>Name</div>
            <div style={{ ...styles.cell, flex: 0.9 }}>Tier</div>
            <div style={{ ...styles.cell, flex: 1.15 }}>Rating</div>
            <div style={{ ...styles.cell, flex: 1.7 }}>Feedback</div>
            <div style={{ ...styles.cell, flex: 1.05 }}>Submitted</div>
            <div style={{ ...styles.cell, flex: 1 }}>Media</div>
            <div style={{ ...styles.cell, flex: 1.05 }}>AI Analysis</div>
          </div>

          {loading ? (
            <div style={styles.emptyMessage}>Loading reviews...</div>
          ) : filteredReviews.length > 0 ? (
            filteredReviews.map((review) => (
              <div
                key={review.id}
                style={styles.tableRow}
                onClick={() => setSelectedReview(review)}
              >
                <div style={{ ...styles.rowCell, flex: 0.9 }}>
                  {shortId(review.id)}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.35 }}>
                  {review.reviewer_name || "-"}
                </div>

                <div style={{ ...styles.rowCell, flex: 0.9 }}>
                  {review.tier || "-"}
                </div>

                <div style={{ ...styles.ratingCell, flex: 1.15 }}>
                  <span style={styles.starText}>
                    {renderStars(review.rating)}
                  </span>
                  <span style={styles.ratingText}>
                    ({Number(review.rating || 0)}/5)
                  </span>
                </div>

                <div style={{ ...styles.feedbackCell, flex: 1.7 }}>
                  {truncateText(review.feedback || "-", 42)}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.05 }}>
                  {formatDateTime(review.submitted_at)}
                </div>

                <div
                  style={{ ...styles.rowCell, flex: 1 }}
                  onClick={(event) => event.stopPropagation()}
                >
                  <button
                    type="button"
                    onClick={() => handleViewMedia(review)}
                    style={{
                      ...styles.mediaButton,
                      ...(review.media_path ? styles.mediaButtonActive : {}),
                    }}
                  >
                    View
                  </button>
                </div>

                <div
                  style={{
                    ...styles.rowCell,
                    flex: 1.05,
                    color: getAnalysisColor(review.ai_analysis),
                  }}
                >
                  {normalizeAnalysis(review.ai_analysis)}
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>No reviews found</div>
          )}
        </div>
      </section>

      {selectedReview && (
        <ReviewDetailPanel
          review={selectedReview}
          onClose={() => setSelectedReview(null)}
          onViewMedia={handleViewMedia}
        />
      )}
    </main>
  );
}

function ReviewDetailPanel({ review, onClose, onViewMedia }) {
  return (
    <div style={styles.overlay}>
      <aside style={styles.detailCard}>
        <button type="button" onClick={onClose} style={styles.closeButton}>
          ×
        </button>

        <h2 style={styles.detailTitle}>Review Details</h2>

        <p style={styles.detailLine}>
          <strong>Review ID:</strong> {shortId(review.id)}
        </p>

        <p style={styles.detailLine}>
          <strong>Name:</strong> {review.reviewer_name || "-"}
        </p>

        <p style={styles.detailLine}>
          <strong>Tier:</strong> {review.tier || "-"}
        </p>

        <p style={styles.detailLine}>
          <strong>Rating:</strong>{" "}
          <span style={styles.starText}>{renderStars(review.rating)}</span>{" "}
          <span style={styles.ratingText}>
            ({Number(review.rating || 0)}/5)
          </span>
        </p>

        <p style={styles.detailParagraph}>
          <strong>Feedback:</strong> {review.feedback || "-"}
        </p>

        <p style={styles.detailLine}>
          <strong>Submitted:</strong> {formatDateTime(review.submitted_at)}
        </p>

        <div style={styles.documentRow}>
          <strong>Documents:</strong>

          <button
            type="button"
            onClick={() => onViewMedia(review)}
            style={{
              ...styles.mediaButton,
              ...(review.media_path ? styles.mediaButtonActive : {}),
            }}
          >
            View
          </button>
        </div>

        <p style={styles.detailLine}>
          <strong>AI Analysis:</strong>{" "}
          <span style={{ color: getAnalysisColor(review.ai_analysis) }}>
            {normalizeAnalysis(review.ai_analysis)}
          </span>
        </p>
      </aside>
    </div>
  );
}

function shortId(id) {
  if (!id) return "-";
  return id.slice(0, 4);
}

function renderStars(rating) {
  const number = Number(rating || 0);
  const filledStars = "★".repeat(number);
  const emptyStars = "☆".repeat(5 - number);

  return filledStars + emptyStars;
}

function normalizeAnalysis(value) {
  if (!value) return "Neutral";

  const lowerValue = value.toLowerCase();

  if (lowerValue === "positive") return "Positive";
  if (lowerValue === "negative") return "Negative";

  return "Neutral";
}

function getAnalysisColor(value) {
  const analysis = normalizeAnalysis(value);

  if (analysis === "Positive") {
    return "#4caf50";
  }

  if (analysis === "Negative") {
    return "#ef4444";
  }

  return "#888888";
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

function SearchIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#8f8f8f"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      style={{ marginRight: "8px", flexShrink: 0 }}
    >
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
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

  filters: {
    display: "flex",
    alignItems: "center",
    gap: "14px",
    flexWrap: "wrap",
    justifyContent: "flex-end",
  },

  select: {
    height: "38px",
    borderRadius: "8px",
    border: "1px solid #cfcfcf",
    padding: "0 10px",
    fontSize: "14px",
    backgroundColor: "#ffffff",
    cursor: "pointer",
  },

  searchBox: {
    height: "38px",
    width: "145px",
    borderRadius: "8px",
    border: "1px solid #cfcfcf",
    display: "flex",
    alignItems: "center",
    padding: "0 10px",
    boxSizing: "border-box",
    backgroundColor: "#ffffff",
  },

  searchInput: {
    border: "none",
    outline: "none",
    width: "100%",
    fontSize: "14px",
    backgroundColor: "transparent",
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
    cursor: "pointer",
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

  mediaButton: {
    width: "74px",
    height: "30px",
    borderRadius: "7px",
    border: "1px solid #cfcfcf",
    backgroundColor: "#ffffff",
    color: "#999999",
    fontSize: "12px",
    fontWeight: "700",
    cursor: "pointer",
  },

  mediaButtonActive: {
    color: "#6658ff",
    border: "1px solid #6658ff",
  },

  emptyMessage: {
    padding: "36px 10px",
    textAlign: "center",
    color: "#888888",
    fontSize: "16px",
  },

  overlay: {
    position: "fixed",
    inset: 0,
    backgroundColor: "rgba(0, 0, 0, 0.55)",
    display: "flex",
    justifyContent: "flex-end",
    alignItems: "flex-start",
    paddingTop: "82px",
    paddingRight: "54px",
    boxSizing: "border-box",
    zIndex: 100,
  },

  detailCard: {
    width: "310px",
    backgroundColor: "#ffffff",
    borderRadius: "14px",
    padding: "26px 24px",
    boxSizing: "border-box",
    position: "relative",
  },

  closeButton: {
    position: "absolute",
    top: "18px",
    right: "18px",
    border: "none",
    backgroundColor: "transparent",
    fontSize: "28px",
    lineHeight: "28px",
    cursor: "pointer",
    color: "#777777",
  },

  detailTitle: {
    fontSize: "20px",
    fontWeight: "700",
    margin: "0 0 16px",
  },

  detailLine: {
    fontSize: "14px",
    lineHeight: "20px",
    margin: "0 0 10px",
  },

  detailParagraph: {
    fontSize: "14px",
    lineHeight: "18px",
    margin: "0 0 10px",
  },

  documentRow: {
    display: "flex",
    alignItems: "center",
    gap: "10px",
    fontSize: "14px",
    margin: "14px 0 10px",
  },

  fileNameText: {
    margin: "0 0 12px 92px",
    fontSize: "11px",
    color: "#777777",
    wordBreak: "break-word",
  },
};