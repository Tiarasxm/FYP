"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";

export default function AdminDashboardPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [selectedRange, setSelectedRange] = useState("7");

  const [dashboardData, setDashboardData] = useState({
    totalUsers: 0,
    approvedPros: 0,
    pendingProApps: 0,
    priorityUsers: 0,
    freeUsers: 0,
    fitnessPros: 0,
    signupsByDay: [0, 0, 0, 0, 0, 0, 0],
    signupLabels: ["", "", "", "", "", "", ""],
    hasSignupDate: true,
  });

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    setAllowed(true);
    fetchDashboardData();
  }, [router, selectedRange]);

  async function fetchCount(query) {
    const { count, error } = await query;

    if (error) {
      console.error("Supabase count error:", error.message);
      return 0;
    }

    return count || 0;
  }

  async function fetchDashboardData() {
    setLoading(true);

    const [
      totalUsers,
      approvedPros,
      pendingProApps,
      priorityUsers,
      freeUsers,
      fitnessPros,
      signupResult,
    ] = await Promise.all([
      fetchCount(
        supabase.from("profiles").select("*", {
          count: "exact",
          head: true,
        })
      ),

      fetchCount(
        supabase
          .from("fitness_professional")
          .select("*", {
            count: "exact",
            head: true,
          })
          .eq("approved", true)
      ),

      fetchPendingProAppsCount(),

      fetchCount(
        supabase
          .from("profiles")
          .select("*", {
            count: "exact",
            head: true,
          })
          .eq("user_type", "Priority")
      ),

      fetchCount(
        supabase
          .from("profiles")
          .select("*", {
            count: "exact",
            head: true,
          })
          .eq("user_type", "Free")
      ),

      fetchCount(
        supabase
          .from("profiles")
          .select("*", {
            count: "exact",
            head: true,
          })
          .eq("user_type", "Fitness professional")
      ),

      fetchNewSignups(),
    ]);

    setDashboardData({
      totalUsers,
      approvedPros,
      pendingProApps,
      priorityUsers,
      freeUsers,
      fitnessPros,
      signupsByDay: signupResult.signupsByDay,
      signupLabels: signupResult.signupLabels,
      hasSignupDate: signupResult.hasSignupDate,
    });

    setLoading(false);
  }

  async function fetchPendingProAppsCount() {
    const { data, error } = await supabase
      .from("fitness_professional")
      .select("profile_id, approved, profiles!inner(status)")
      .or("approved.eq.false,approved.is.null")
      .neq("profiles.status", "rejected");

    if (error) {
      console.error("Pending pro apps count error:", error.message);
      return 0;
    }

    return data?.length || 0;
  }

  async function fetchNewSignups() {
    const rangeDays = Number(selectedRange);

    const endDate = new Date();
    endDate.setHours(23, 59, 59, 999);

    const startDate = new Date();
    startDate.setDate(endDate.getDate() - rangeDays + 1);
    startDate.setHours(0, 0, 0, 0);

    const { data, error } = await supabase
      .from("profiles")
      .select("created_at")
      .gte("created_at", startDate.toISOString())
      .lte("created_at", endDate.toISOString());

    if (error) {
      console.warn("New Signups chart needs created_at column:", error.message);

      return {
        signupsByDay: [0, 0, 0, 0, 0, 0, 0],
        signupLabels: ["", "", "", "", "", "", ""],
        hasSignupDate: false,
      };
    }

    const bucketCount = 7;
    const bucketSize = Math.ceil(rangeDays / bucketCount);
    const result = Array(bucketCount).fill(0);
    const labels = Array(bucketCount).fill("");

    for (let index = 0; index < bucketCount; index++) {
      const labelDate = new Date(startDate);
      const dayOffset = Math.min(index * bucketSize, rangeDays - 1);
      labelDate.setDate(startDate.getDate() + dayOffset);
      labels[index] = formatChartDate(labelDate);
    }

    data.forEach((user) => {
      if (!user.created_at) return;

      const createdDate = new Date(user.created_at);
      createdDate.setHours(0, 0, 0, 0);

      const diffTime = createdDate.getTime() - startDate.getTime();
      const diffDay = Math.floor(diffTime / (1000 * 60 * 60 * 24));

      if (diffDay >= 0 && diffDay < rangeDays) {
        const bucketIndex = Math.min(
          Math.floor(diffDay / bucketSize),
          bucketCount - 1
        );

        result[bucketIndex] += 1;
      }
    });

    return {
      signupsByDay: result,
      signupLabels: labels,
      hasSignupDate: true,
    };
  }

  if (!allowed) {
    return null;
  }

  const totalTier =
    dashboardData.freeUsers +
    dashboardData.priorityUsers +
    dashboardData.fitnessPros;

  const freePercent =
    totalTier === 0
      ? 0
      : Math.round((dashboardData.freeUsers / totalTier) * 100);

  const priorityPercent =
    totalTier === 0
      ? 0
      : Math.round((dashboardData.priorityUsers / totalTier) * 100);

  const proPercent =
    totalTier === 0 ? 0 : 100 - freePercent - priorityPercent;

  const pieData = [
    {
      label: "Free",
      value: dashboardData.freeUsers,
      percent: freePercent,
      color: "#2d7fb8",
    },
    {
      label: "Priority",
      value: dashboardData.priorityUsers,
      percent: priorityPercent,
      color: "#ff9800",
    },
    {
      label: "Pro",
      value: dashboardData.fitnessPros,
      percent: proPercent,
      color: "#2ca02c",
    },
  ];

  const pieSlices = buildPieSlices(pieData);

  const signupPoints = getSignupChartPoints(dashboardData.signupsByDay);
  const signupPolyline = signupPoints.map(([x, y]) => `${x},${y}`).join(" ");

  return (
    <main style={styles.page}>
      <AdminSidebar />

      <section style={styles.content}>
        <div style={styles.topBar}>
          <select
            value={selectedRange}
            onChange={(event) => setSelectedRange(event.target.value)}
            style={styles.select}
          >
            <option value="7">Last 7 days</option>
            <option value="30">Last 30 days</option>
            <option value="90">Last 90 days</option>
          </select>
        </div>

        <div style={styles.statsGrid}>
          <StatCard
            title="Total Users"
            value={loading ? "Loading..." : formatNumber(dashboardData.totalUsers)}
          />

          <StatCard
            title="Approved Pros"
            value={
              loading ? "Loading..." : formatNumber(dashboardData.approvedPros)
            }
          />

          <div style={styles.statCard}>
            <div style={styles.cardHeader}>
              <h3 style={styles.statTitle}>Pending Pro Apps</h3>
              {dashboardData.pendingProApps > 0 && (
                <span style={styles.redDot}></span>
              )}
            </div>

            <p style={styles.statValue}>
              {loading
                ? "Loading..."
                : formatNumber(dashboardData.pendingProApps)}
            </p>

            <button
              onClick={() => router.push("/admin/professionals?status=pending")}
              style={styles.reviewButton}
            >Review</button>
          </div>

          <StatCard
            title="Priority Users"
            value={
              loading ? "Loading..." : formatNumber(dashboardData.priorityUsers)
            }
          />
        </div>

        <div style={styles.chartGrid}>
          <div style={styles.chartCard}>
            <h3 style={styles.chartTitle}>User Tier Breakdown</h3>

            <div style={styles.pieArea}>
              <svg viewBox="0 0 240 240" style={styles.pieSvg}>
                {totalTier === 0 ? (
                  <>
                    <circle cx="120" cy="120" r="100" fill="#e5e5e5" />
                    <text
                      x="120"
                      y="124"
                      textAnchor="middle"
                      fontSize="14"
                      fontWeight="700"
                      fill="#ffffff"
                    >
                      0%
                    </text>
                  </>
                ) : (
                  <>
                    {pieSlices.map((slice) => (
                      <path key={slice.label} d={slice.path} fill={slice.color} />
                    ))}

                    {pieSlices.map((slice) => (
                      <text
                        key={`${slice.label}-label`}
                        x={slice.labelX}
                        y={slice.labelY}
                        textAnchor="middle"
                        dominantBaseline="middle"
                        fontSize="13"
                        fontWeight="700"
                        fill="#ffffff"
                      >
                        {slice.percent}%
                      </text>
                    ))}
                  </>
                )}
              </svg>

              <div style={styles.legend}>
                <Legend
                  color="#2d7fb8"
                  label={`Free (${dashboardData.freeUsers})`}
                />
                <Legend
                  color="#ff9800"
                  label={`Priority (${dashboardData.priorityUsers})`}
                />
                <Legend
                  color="#2ca02c"
                  label={`Pro (${dashboardData.fitnessPros})`}
                />
              </div>
            </div>
          </div>

          <div style={styles.chartCard}>
            <h3 style={styles.chartTitle}>New Signups</h3>

            <svg viewBox="0 0 500 280" style={styles.lineChart}>
              {[35, 69, 103, 137, 171, 205].map((y) => (
                <line
                  key={`h-${y}`}
                  x1="50"
                  y1={y}
                  x2="460"
                  y2={y}
                  stroke="#d7d7d7"
                  strokeWidth="1"
                />
              ))}

              {[50, 118, 186, 254, 322, 390, 458].map((x) => (
                <line
                  key={`v-${x}`}
                  x1={x}
                  y1="35"
                  x2={x}
                  y2="205"
                  stroke="#d7d7d7"
                  strokeWidth="1"
                />
              ))}

              <line
                x1="50"
                y1="205"
                x2="460"
                y2="205"
                stroke="#777777"
                strokeWidth="1.5"
              />

              <line
                x1="50"
                y1="35"
                x2="50"
                y2="205"
                stroke="#777777"
                strokeWidth="1.5"
              />

              {dashboardData.hasSignupDate ? (
                <>
                  <polyline
                    points={signupPolyline}
                    fill="none"
                    stroke="#1683d8"
                    strokeWidth="3"
                  />

                  {signupPoints.map(([x, y], index) => (
                    <g key={index}>
                      <circle
                        cx={x}
                        cy={y}
                        r="6"
                        fill="#5dade2"
                        stroke="#1683d8"
                        strokeWidth="2"
                      />

                      <text
                        x={x}
                        y={Math.max(y - 12, 18)}
                        textAnchor="middle"
                        fontSize="12"
                        fontWeight="700"
                        fill="#111111"
                      >
                        {dashboardData.signupsByDay[index]}
                      </text>

                      <text
                        x={x}
                        y="232"
                        textAnchor="middle"
                        fontSize="11"
                        fontWeight="600"
                        fill="#555555"
                      >
                        {dashboardData.signupLabels[index]}
                      </text>
                    </g>
                  ))}
                </>
              ) : (
                <text
                  x="250"
                  y="135"
                  textAnchor="middle"
                  fontSize="15"
                  fontWeight="700"
                  fill="#777777"
                >
                  Add created_at column to show signup trend
                </text>
              )}
            </svg>
          </div>
        </div>
      </section>
    </main>
  );
}

function buildPieSlices(pieData) {
  const total = pieData.reduce((sum, item) => sum + item.value, 0);

  if (total === 0) {
    return [];
  }

  let currentAngle = 0;

  return pieData
    .filter((item) => item.value > 0)
    .map((item) => {
      const angle = (item.value / total) * 360;
      const startAngle = currentAngle;
      const endAngle = currentAngle + angle;
      const midAngle = startAngle + angle / 2;

      currentAngle = endAngle;

      const path = describePieSlice(120, 120, 100, startAngle, endAngle);
      const labelPosition = polarToCartesian(120, 120, 58, midAngle);

      return {
        ...item,
        path,
        labelX: labelPosition.x,
        labelY: labelPosition.y,
      };
    });
}

function describePieSlice(cx, cy, radius, startAngle, endAngle) {
  const finalEndAngle =
    endAngle - startAngle >= 360 ? startAngle + 359.999 : endAngle;

  const start = polarToCartesian(cx, cy, radius, startAngle);
  const end = polarToCartesian(cx, cy, radius, finalEndAngle);
  const largeArcFlag = finalEndAngle - startAngle > 180 ? 1 : 0;

  return [
    `M ${cx} ${cy}`,
    `L ${start.x} ${start.y}`,
    `A ${radius} ${radius} 0 ${largeArcFlag} 1 ${end.x} ${end.y}`,
    "Z",
  ].join(" ");
}

function polarToCartesian(cx, cy, radius, angleInDegrees) {
  const angleInRadians = ((angleInDegrees - 90) * Math.PI) / 180;

  return {
    x: cx + radius * Math.cos(angleInRadians),
    y: cy + radius * Math.sin(angleInRadians),
  };
}

function getSignupChartPoints(signupsByDay) {
  const xPositions = [50, 118, 186, 254, 322, 390, 458];
  const chartTop = 35;
  const chartBottom = 205;
  const chartHeight = chartBottom - chartTop;
  const maxValue = Math.max(...signupsByDay, 1);

  return signupsByDay.map((value, index) => {
    const y = chartBottom - (value / maxValue) * chartHeight;
    return [xPositions[index], y];
  });
}

function formatChartDate(date) {
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function formatNumber(value) {
  return Number(value).toLocaleString();
}

function StatCard({ title, value }) {
  return (
    <div style={styles.statCard}>
      <h3 style={styles.statTitle}>{title}</h3>
      <p style={styles.statValue}>{value}</p>
    </div>
  );
}

function Legend({ color, label }) {
  return (
    <div style={styles.legendItem}>
      <span style={{ ...styles.legendColor, backgroundColor: color }}></span>
      <span>{label}</span>
    </div>
  );
}

const styles = {
  page: {
    minHeight: "100vh",
    display: "flex",
    backgroundColor: "#f8f8ff",
    fontFamily: "Arial, sans-serif",
    color: "#000000",
  },

  content: {
    flex: 1,
    padding: "70px 100px",
    boxSizing: "border-box",
  },

  topBar: {
    display: "flex",
    justifyContent: "flex-end",
    marginBottom: "18px",
  },

  select: {
    width: "155px",
    height: "42px",
    borderRadius: "8px",
    border: "1px solid #cfcfcf",
    backgroundColor: "#ffffff",
    padding: "0 12px",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
  },

  statsGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(4, 1fr)",
    gap: "30px",
    marginBottom: "48px",
  },

  statCard: {
    height: "170px",
    backgroundColor: "#ffffff",
    borderRadius: "10px",
    padding: "30px 20px",
    boxSizing: "border-box",
    boxShadow: "0 12px 24px rgba(0, 0, 0, 0.06)",
  },

  cardHeader: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
  },

  statTitle: {
    fontSize: "16px",
    fontWeight: "700",
    margin: "0 0 14px",
  },

  statValue: {
    fontSize: "28px",
    fontWeight: "700",
    margin: "0",
  },

  redDot: {
    width: "12px",
    height: "12px",
    borderRadius: "50%",
    backgroundColor: "#e5484d",
    display: "inline-block",
    marginBottom: "12px",
  },

  reviewButton: {
    marginTop: "14px",
    width: "90px",
    height: "34px",
    border: "none",
    borderRadius: "18px",
    backgroundColor: "#6658ff",
    color: "#ffffff",
    fontSize: "14px",
    fontWeight: "700",
    cursor: "pointer",
  },

  chartGrid: {
    display: "grid",
    gridTemplateColumns: "1fr 1.2fr",
    gap: "28px",
  },

  chartCard: {
    height: "350px",
    backgroundColor: "#ffffff",
    borderRadius: "18px",
    padding: "34px 30px",
    boxSizing: "border-box",
    boxShadow: "0 12px 24px rgba(0, 0, 0, 0.05)",
  },

  chartTitle: {
    fontSize: "17px",
    fontWeight: "700",
    margin: "0 0 20px",
  },

  pieArea: {
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "30px",
  },

  pieSvg: {
    width: "230px",
    height: "230px",
  },

  legend: {
    display: "flex",
    flexDirection: "column",
    gap: "8px",
    fontSize: "12px",
  },

  legendItem: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
  },

  legendColor: {
    width: "9px",
    height: "9px",
    display: "inline-block",
  },

  lineChart: {
    width: "100%",
    height: "260px",
  },
};