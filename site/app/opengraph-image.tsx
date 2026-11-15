import { ImageResponse } from "next/og";

// Image Open Graph générée au build, police par défaut : aucune ressource distante.
export const alt = "Passeport Créateur — votre réputation vous appartient";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "72px 80px",
          backgroundImage: "radial-gradient(circle at 75% 40%, rgba(124,92,255,0.35), rgba(5,6,10,0) 60%)",
          backgroundColor: "#05060A",
          color: "#F5F5F7",
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", maxWidth: 640 }}>
          <div style={{ fontSize: 26, letterSpacing: 4, color: "#A8A8B8" }}>PASSEPORT CRÉATEUR</div>
          <div style={{ display: "flex", flexWrap: "wrap", marginTop: 24, fontSize: 82, fontWeight: 700, lineHeight: 1.02 }}>
            <span>Votre réputation vous&nbsp;</span>
            <span style={{ color: "#3DF5FF" }}>appartient.</span>
          </div>
          <div style={{ marginTop: 28, fontSize: 28, color: "#A8A8B8" }}>
            Certifié par vos pairs · Lisible par tous · Prototype testnet
          </div>
        </div>
        <div
          style={{
            width: 300,
            height: 420,
            display: "flex",
            flexDirection: "column",
            justifyContent: "space-between",
            padding: 32,
            borderRadius: 24,
            border: "2px solid rgba(61,245,255,0.45)",
            background: "rgba(255,255,255,0.05)",
            transform: "rotate(6deg)",
          }}
        >
          <div style={{ fontSize: 16, letterSpacing: 2, color: "#A8A8B8" }}>PASSEPORT CRÉATEUR</div>
          <div style={{ display: "flex", flexDirection: "column" }}>
            <div style={{ fontSize: 16, color: "#A8A8B8" }}>Niveau</div>
            <div style={{ fontSize: 110, fontWeight: 700, color: "#3DF5FF", lineHeight: 1 }}>3</div>
          </div>
        </div>
      </div>
    ),
    size
  );
}
