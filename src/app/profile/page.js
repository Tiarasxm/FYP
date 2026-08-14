"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Navbar from "@/app/components/Navbar";

const genderOptions = ["Male", "Female", "Other"];

const activityLevelOptions = [
  "Sedentary",
  "Lightly Active",
  "Moderately Active",
  "Very Active",
];

const fitnessGoalOptions = [
  "Get Fitter",
  "Gain Weight",
  "Lose Weight",
  "Improve Endurance",
  "Build Muscles",
];

const inputClass =
  "w-full h-[46px] border border-gray-300 rounded-lg px-4 text-[14px] outline-none focus:border-[#6c5cff]";

export default function ProfilePage() {
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");

  const [userId, setUserId] = useState(null);
  const [email, setEmail] = useState("");
  const [userType, setUserType] = useState("");

  const [fullName, setFullName] = useState("");
  const [gender, setGender] = useState(genderOptions[0]);
  const [dateOfBirth, setDateOfBirth] = useState("");
  const [weightKg, setWeightKg] = useState("");
  const [heightCm, setHeightCm] = useState("");
  const [activityLevel, setActivityLevel] = useState(activityLevelOptions[0]);
  const [fitnessGoal, setFitnessGoal] = useState(fitnessGoalOptions[0]);
  const [isPrivate, setIsPrivate] = useState(false);

  async function loadProfile() {
    setLoading(true);

    const { data: userData, error: userError } = await supabase.auth.getUser();

    if (userError || !userData?.user) {
      router.replace("/login");
      return;
    }

    const user = userData.user;
    setUserId(user.id);

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select(
        "full_name, email, gender, user_type, date_of_birth, weight_kg, height_cm, activity_level, fitness_goal, is_private"
      )
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      setErrorMessage("Failed to load your profile. Please refresh the page.");
      setLoading(false);
      return;
    }

    setFullName(profile.full_name || "");
    setEmail(profile.email || user.email || "");
    setUserType(profile.user_type || "");
    setGender(profile.gender || genderOptions[0]);
    setDateOfBirth(profile.date_of_birth || "");
    setWeightKg(profile.weight_kg != null ? String(profile.weight_kg) : "");
    setHeightCm(profile.height_cm != null ? String(profile.height_cm) : "");
    setActivityLevel(profile.activity_level || activityLevelOptions[0]);
    setFitnessGoal(profile.fitness_goal || fitnessGoalOptions[0]);
    setIsPrivate(profile.is_private === true);

    setLoading(false);
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- setState calls happen after network awaits, not synchronously
    loadProfile();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- intentionally run once on mount
  }, []);

  async function handleSave(event) {
    event.preventDefault();

    if (!userId) {
      return;
    }

    setSaving(true);
    setSuccessMessage("");
    setErrorMessage("");

    const updates = {
      full_name: fullName.trim(),
      gender,
      date_of_birth: dateOfBirth || null,
      is_private: isPrivate,
    };

    if (!isFitnessProfessional) {
      updates.weight_kg = weightKg === "" ? null : Number(weightKg);
      updates.height_cm = heightCm === "" ? null : Number(heightCm);
      updates.activity_level = activityLevel;
      updates.fitness_goal = fitnessGoal;
    }

    const { error } = await supabase
      .from("profiles")
      .update(updates)
      .eq("id", userId);

    if (error) {
      setErrorMessage(error.message || "Failed to update your profile.");
      setSaving(false);
      return;
    }

    setSuccessMessage("Profile updated successfully.");
    setSaving(false);
  }

  const avatarLetter = fullName.trim() ? fullName.trim()[0].toUpperCase() : "?";
  const isFitnessProfessional =
    userType.trim().toLowerCase() === "fitness professional";

  if (loading) {
    return (
      <main className="min-h-screen bg-[#f8f8ff] text-black flex flex-col">
        <Navbar />
        <div className="flex-1 flex items-center justify-center">
          <p className="text-gray-500 text-[14px]">Loading your profile...</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black flex flex-col">
      <Navbar />

      <section className="flex-1 px-6 md:px-10 py-16">
        <div className="max-w-[640px] mx-auto">
          <h1 className="text-[24px] font-bold text-center">My Profile</h1>
          <p className="mt-2 text-[13px] text-gray-500 text-center">
            View and update your account details.
          </p>

          <div className="mt-10 bg-white rounded-[20px] shadow-sm p-8">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-full bg-[#6c5cff] text-white flex items-center justify-center text-[22px] font-bold">
                {avatarLetter}
              </div>

              <div>
                <p className="text-[16px] font-bold">
                  {fullName || "Unnamed user"}
                </p>
                <span className="inline-block mt-1 bg-[#f0eeff] text-[#6c5cff] text-[11px] font-semibold px-3 py-1 rounded-full">
                  {userType || "-"}
                </span>
              </div>
            </div>

            {successMessage && (
              <p className="mt-6 text-[13px] text-green-600 font-semibold">
                {successMessage}
              </p>
            )}

            {errorMessage && (
              <p className="mt-6 text-[13px] text-red-600 font-semibold">
                {errorMessage}
              </p>
            )}

            <form onSubmit={handleSave} className="mt-6 space-y-5">
              <Field label="Email">
                <input
                  type="email"
                  value={email}
                  disabled
                  className={`${inputClass} bg-gray-50 text-gray-500 border-gray-200`}
                />
              </Field>

              <Field label="Full Name">
                <input
                  type="text"
                  value={fullName}
                  onChange={(event) => setFullName(event.target.value)}
                  className={inputClass}
                />
              </Field>

              <Field label="Gender">
                <select
                  value={gender}
                  onChange={(event) => setGender(event.target.value)}
                  className={inputClass}
                >
                  {genderOptions.map((option) => (
                    <option key={option} value={option}>
                      {option}
                    </option>
                  ))}
                </select>
              </Field>

              <Field label="Date of Birth">
                <input
                  type="date"
                  value={dateOfBirth}
                  onChange={(event) => setDateOfBirth(event.target.value)}
                  className={inputClass}
                />
              </Field>

              {!isFitnessProfessional && (
                <>
                  <div className="grid grid-cols-2 gap-4">
                    <Field label="Weight (kg)">
                      <input
                        type="number"
                        step="0.1"
                        value={weightKg}
                        onChange={(event) => setWeightKg(event.target.value)}
                        className={inputClass}
                      />
                    </Field>

                    <Field label="Height (cm)">
                      <input
                        type="number"
                        step="0.1"
                        value={heightCm}
                        onChange={(event) => setHeightCm(event.target.value)}
                        className={inputClass}
                      />
                    </Field>
                  </div>

                  <Field label="Activity Level">
                    <select
                      value={activityLevel}
                      onChange={(event) => setActivityLevel(event.target.value)}
                      className={inputClass}
                    >
                      {activityLevelOptions.map((option) => (
                        <option key={option} value={option}>
                          {option}
                        </option>
                      ))}
                    </select>
                  </Field>

                  <Field label="Fitness Goal">
                    <select
                      value={fitnessGoal}
                      onChange={(event) => setFitnessGoal(event.target.value)}
                      className={inputClass}
                    >
                      {fitnessGoalOptions.map((option) => (
                        <option key={option} value={option}>
                          {option}
                        </option>
                      ))}
                    </select>
                  </Field>
                </>
              )}

              <label className="flex items-center gap-3 text-[14px] text-gray-700">
                <input
                  type="checkbox"
                  checked={isPrivate}
                  onChange={(event) => setIsPrivate(event.target.checked)}
                  className="w-4 h-4 accent-[#6c5cff]"
                />
                Keep my profile private
              </label>

              <button
                type="submit"
                disabled={saving}
                className="w-full h-[48px] bg-[#6c5cff] text-white rounded-xl text-[14px] font-semibold hover:bg-[#5b4bea] disabled:opacity-60"
              >
                {saving ? "Saving..." : "Save Changes"}
              </button>
            </form>

            {isFitnessProfessional && (
              <p className="mt-5 text-[12px] text-gray-500">
                Your professional details — display name, bio, experience,
                specialisations and certificate — are managed in the
                ShapeRush app.
              </p>
            )}
          </div>
        </div>
      </section>
    </main>
  );
}

function Field({ label, children }) {
  return (
    <div>
      <label className="block text-[13px] font-medium mb-2">{label}</label>
      {children}
    </div>
  );
}
