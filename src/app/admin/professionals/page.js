"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";
import { createAuditLog } from "@/lib/adminAuditLog";

export default function AdminProfessionalsPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);

  const [professionals, setProfessionals] = useState([]);
  const [specializationFilter, setSpecializationFilter] =
    useState("All Specializations");
  const [statusFilter, setStatusFilter] = useState("All Status");
  const [searchKeyword, setSearchKeyword] = useState("");

  const [selectedProfessional, setSelectedProfessional] = useState(null);

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    setAllowed(true);
    fetchProfessionals();
  }, [router]);

  async function fetchProfessionals() {
    setLoading(true);

    const { data, error } = await supabase
      .from("fitness_professional")
      .select(
        "profile_id, display_name, bio, experience, specializations, certificate_name, certificate_path, approved, submitted_at, profiles!inner(full_name, email, status, created_at)"
      )
      .order("submitted_at", { ascending: false });

    if (error) {
      console.error("Fetch professionals error:", error.message);
      setProfessionals([]);
      setLoading(false);
      return;
    }

    const formattedProfessionals = (data || [])
      .filter((professional) => professional.profiles?.status !== "rejected")
      .map((professional) => ({
        id: professional.profile_id,
        shortId: shortId(professional.profile_id),
        name:
          professional.display_name ||
          professional.profiles?.full_name ||
          "Not provided",
        email: professional.profiles?.email || "-",
        bio: professional.bio || "",
        experience: professional.experience,
        specializations: professional.specializations || "-",
        certificateName: professional.certificate_name || "",
        certificatePath: professional.certificate_path || "",
        status: getProfessionalStatus({
          status: professional.profiles?.status,
          approved: professional.approved,
        }),
        rawStatus: professional.profiles?.status,
        approved: professional.approved,
        submittedAt: professional.submitted_at,
        createdAt: professional.profiles?.created_at,
      }));

    setProfessionals(formattedProfessionals);
    setLoading(false);
  }

  async function handleToggleStatus(event, professional) {
    event.stopPropagation();

    if (professional.status === "Pending") {
      router.push("/admin/pending-professionals");
      return;
    }

    const nextStatus =
      professional.status === "Suspended" ? "active" : "suspended";

    const confirmMessage =
      professional.status === "Suspended"
        ? `Unsuspend ${professional.name}?`
        : `Restrict ${professional.name}?`;

    const confirmed = window.confirm(confirmMessage);

    if (!confirmed) return;

    const { error } = await supabase
      .from("profiles")
      .update({
        status: nextStatus,
      })
      .eq("id", professional.id);

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action:
        nextStatus === "suspended"
          ? "suspend_professional"
          : "unsuspend_professional",
      target: professional.id,
      targetType: "professional",
    });

    setProfessionals((currentProfessionals) =>
      currentProfessionals.map((item) =>
        item.id === professional.id
          ? {
              ...item,
              status: nextStatus === "suspended" ? "Suspended" : "Active",
              rawStatus: nextStatus,
            }
          : item
      )
    );

    if (selectedProfessional?.id === professional.id) {
      setSelectedProfessional((current) => ({
        ...current,
        status: nextStatus === "suspended" ? "Suspended" : "Active",
        rawStatus: nextStatus,
      }));
    }
  }

  function handleViewDocument(professional) {
    if (!professional.certificatePath) {
      alert("No document uploaded.");
      return;
    }

    const { data } = supabase.storage
      .from("certifications")
      .getPublicUrl(professional.certificatePath);

    if (!data?.publicUrl) {
      alert("Unable to open document.");
      return;
    }

    window.open(data.publicUrl, "_blank", "noopener,noreferrer");
  }

  const specializationOptions = useMemo(() => {
    const options = new Set();

    professionals.forEach((professional) => {
      if (!professional.specializations || professional.specializations === "-") {
        return;
      }

      professional.specializations.split(",").forEach((item) => {
        const value = item.trim();

        if (value) {
          options.add(value);
        }
      });
    });

    return ["All Specializations", ...Array.from(options).sort()];
  }, [professionals]);

  const filteredProfessionals = professionals.filter((professional) => {
    const keyword = searchKeyword.trim().toLowerCase();

    const matchSearch =
      keyword === "" ||
      professional.shortId.toLowerCase().includes(keyword) ||
      professional.name.toLowerCase().includes(keyword) ||
      professional.email.toLowerCase().includes(keyword) ||
      professional.specializations.toLowerCase().includes(keyword);

    const matchSpecialization =
      specializationFilter === "All Specializations" ||
      professional.specializations
        .toLowerCase()
        .includes(specializationFilter.toLowerCase());

    const matchStatus =
      statusFilter === "All Status" || professional.status === statusFilter;

    return matchSearch && matchSpecialization && matchStatus;
  });

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
              Fitness Professionals{" "}
              <span style={styles.count}>
                ({loading ? "..." : formatNumber(professionals.length)})
              </span>
            </h2>

            <div style={styles.filters}>
              <select
                style={styles.select}
                value={specializationFilter}
                onChange={(event) =>
                  setSpecializationFilter(event.target.value)
                }
              >
                {specializationOptions.map((option) => (
                  <option key={option}>{option}</option>
                ))}
              </select>

              <select
                style={styles.select}
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value)}
              >
                <option>All Status</option>
                <option>Active</option>
                <option>Suspended</option>
                <option>Pending</option>
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
            <div style={{ ...styles.cell, flex: 0.9 }}>ID</div>
            <div style={{ ...styles.cell, flex: 1.6 }}>Name</div>
            <div style={{ ...styles.cell, flex: 2.4 }}>Email</div>
            <div style={{ ...styles.cell, flex: 2.2 }}>Specializations</div>
            <div style={{ ...styles.cell, flex: 1.1 }}>Status</div>
            <div style={{ ...styles.cell, flex: 1.2 }}></div>
          </div>

          {loading ? (
            <div style={styles.emptyMessage}>Loading professionals...</div>
          ) : filteredProfessionals.length > 0 ? (
            filteredProfessionals.map((professional) => (
              <div
                key={professional.id}
                style={styles.tableRow}
                onClick={() => setSelectedProfessional(professional)}
              >
                <div style={{ ...styles.rowCell, flex: 0.9 }}>
                  {professional.shortId}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.6 }}>
                  {professional.name}
                </div>

                <div style={{ ...styles.rowCell, flex: 2.4 }}>
                  {professional.email}
                </div>

                <div style={{ ...styles.rowCell, flex: 2.2 }}>
                  {truncateText(professional.specializations, 30)}
                </div>

                <div
                  style={{
                    ...styles.rowCell,
                    flex: 1.1,
                    color: getStatusColor(professional.status),
                  }}
                >
                  {professional.status}
                </div>

                <div
                  style={{
                    ...styles.rowCell,
                    flex: 1.2,
                    justifyContent: "flex-end",
                    display: "flex",
                  }}
                >
                  <button
                    onClick={(event) =>
                      handleToggleStatus(event, professional)
                    }
                    style={getActionButtonStyle(professional.status)}
                  >
                    {getActionButtonText(professional.status)}
                  </button>
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>No professionals found</div>
          )}
        </div>
      </section>

      {selectedProfessional && (
        <ProfessionalDetailPanel
          professional={selectedProfessional}
          onClose={() => setSelectedProfessional(null)}
          onViewDocument={handleViewDocument}
        />
      )}
    </main>
  );
}

function ProfessionalDetailPanel({ professional, onClose, onViewDocument }) {
  return (
    <div style={styles.overlay}>
      <aside style={styles.detailCard}>
        <button type="button" onClick={onClose} style={styles.closeButton}>
          ×
        </button>

        <h2 style={styles.detailTitle}>User Details</h2>

        <p style={styles.detailLine}>
          <strong>ID:</strong> {professional.shortId}
        </p>

        <p style={styles.detailLine}>
          <strong>Name:</strong> {professional.name}
        </p>

        <p style={styles.detailLine}>
          <strong>Email:</strong> {professional.email}
        </p>

        <p style={styles.detailParagraph}>
          <strong>Specializations:</strong> {professional.specializations}
        </p>

        <p style={styles.detailLine}>
          <strong>Years Exp:</strong>{" "}
          {professional.experience === null ||
          professional.experience === undefined
            ? "Not provided"
            : professional.experience}
        </p>

        <p style={styles.detailLine}>
          <strong>Status:</strong> {professional.status}
        </p>

        <div style={styles.documentRow}>
          <strong>Documents:</strong>

          <button
            type="button"
            onClick={() => onViewDocument(professional)}
            style={{
              ...styles.documentButton,
              ...(professional.certificatePath
                ? styles.documentButtonActive
                : {}),
            }}
          >
            View {professional.certificatePath ? "(1)" : "(0)"}
          </button>
        </div>

        {professional.certificateName && (
          <p style={styles.fileNameText}>{professional.certificateName}</p>
        )}
      </aside>
    </div>
  );
}

function getProfessionalStatus(professional) {
  if (professional.status === "suspended") {
    return "Suspended";
  }

  if (professional.status === "pending") {
    return "Pending";
  }

  if (professional.approved === false || professional.approved === null) {
    return "Pending";
  }

  return "Active";
}

function getStatusColor(status) {
  if (status === "Suspended") {
    return "#ef4444";
  }

  if (status === "Pending") {
    return "#c99300";
  }

  return "#4caf50";
}

function getActionButtonText(status) {
  if (status === "Suspended") {
    return "Unsuspend";
  }

  if (status === "Pending") {
    return "Review";
  }

  return "Restrict";
}

function getActionButtonStyle(status) {
  if (status === "Suspended") {
    return styles.unsuspendButton;
  }

  if (status === "Pending") {
    return styles.reviewButton;
  }

  return styles.restrictButton;
}

function shortId(id) {
  if (!id) return "-";
  return id.slice(0, 4);
}

function truncateText(text, maxLength) {
  if (!text) return "-";

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength)}...`;
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
    gap: "20px",
  },

  title: {
    fontSize: "24px",
    fontWeight: "700",
    margin: 0,
  },

  count: {
    color: "#9b9b9b",
    fontWeight: "500",
  },

  filters: {
    display: "flex",
    alignItems: "center",
    gap: "18px",
    flexWrap: "wrap",
  },

  select: {
    height: "42px",
    borderRadius: "10px",
    border: "1px solid #cfcfcf",
    padding: "0 14px",
    fontSize: "15px",
    backgroundColor: "#ffffff",
    cursor: "pointer",
  },

  searchBox: {
    height: "42px",
    width: "266px",
    borderRadius: "10px",
    border: "1px solid #cfcfcf",
    display: "flex",
    alignItems: "center",
    padding: "0 12px",
    boxSizing: "border-box",
    backgroundColor: "#ffffff",
  },

  searchInput: {
    border: "none",
    outline: "none",
    width: "100%",
    fontSize: "15px",
    backgroundColor: "transparent",
  },

  tableHeader: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #dddddd",
    padding: "18px 10px",
    color: "#8e8e8e",
    fontSize: "15px",
  },

  tableRow: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #e5e5e5",
    padding: "18px 10px",
    minHeight: "78px",
    boxSizing: "border-box",
    cursor: "pointer",
  },

  cell: {
    fontWeight: "500",
  },

  rowCell: {
    fontSize: "15px",
    display: "flex",
    alignItems: "center",
  },

  restrictButton: {
    minWidth: "102px",
    height: "40px",
    border: "none",
    borderRadius: "20px",
    backgroundColor: "#efefef",
    color: "#222222",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
    padding: "0 18px",
  },

  unsuspendButton: {
    minWidth: "102px",
    height: "40px",
    border: "none",
    borderRadius: "20px",
    backgroundColor: "#f5bcbc",
    color: "#222222",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
    padding: "0 18px",
  },

  reviewButton: {
    minWidth: "102px",
    height: "40px",
    border: "none",
    borderRadius: "20px",
    backgroundColor: "#f3d84e",
    color: "#222222",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
    padding: "0 18px",
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
    marginTop: "14px",
  },

  documentButton: {
    width: "76px",
    height: "28px",
    borderRadius: "6px",
    border: "1px solid #cfcfcf",
    backgroundColor: "#ffffff",
    color: "#999999",
    fontSize: "12px",
    fontWeight: "700",
    cursor: "pointer",
  },

  documentButtonActive: {
    color: "#6658ff",
    border: "1px solid #6658ff",
  },

  fileNameText: {
    margin: "8px 0 0 92px",
    fontSize: "11px",
    color: "#777777",
    wordBreak: "break-word",
  },
};