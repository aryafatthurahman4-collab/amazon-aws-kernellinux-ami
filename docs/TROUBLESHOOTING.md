# Troubleshooting — AWS Sign-In & Account Activation

This covers the exact errors in your screenshots (Oct 2026).

---

## 1. "Email ini sudah dikaitkan dengan ID AWS Builder" (Builder ID sign-in error)

**Full message:** *Email ini sudah dikaitkan dengan ID AWS Builder menggunakan metode masuk yang berbeda (email dan kata sandi, Google, GitHub, dll.). Masuk dengan metode asli Anda untuk melanjutkan.*

**What it means:** That email already created an **AWS Builder ID** with a *different* login method. Builder IDs are separate from AWS root / IAM users. You must use the *original* method.

**Fix (in order):**

1. Go to the Builder ID sign-in and click **"Coba opsi lain yang tersedia / Try other options"**.
2. Try each method you may have used for that email:
   - Email + password
   - Google (your screenshot shows `.../oidc/callback?state=...&iss=https://accounts.google.com` — so you tried Google; try email+password instead)
   - GitHub
3. Check which one succeeds. Request ID from your screenshot (`c3c468d3-0d6d-4323-843d-8c4ae9535424`, Sun 11 Oct 2026 00:27:46 GMT) can be given to AWS Support if you open a case.
4. Do NOT create a second Builder ID with the same email — it will keep failing.
5. Remember the three separate identity systems:
   - **AWS Builder ID** → Skill Builder, re:Post, IAM Identity Center (`view.awsapps.com/start`)
   - **AWS root user** → `aryafatthurahman4@gmail.com (3346-0272-7371)` in your "Choose AWS sessions" screenshot — this login is working
   - **IAM user** → Account ID/alias + username + password (your `ap-southeast-1.signin.aws.amazon.com/oauth` screenshot)

If you forgot the original method, use account recovery with the same email + phone (`arya...@gmail.com`, `+62 0895...` in your MFA screenshot) and register a second MFA device while you still have access.

---

## 2. "Complete your account setup" + Payment Information (Indonesia)

**Page:** `signup.aws.amazon.com/billing/signup/...#/paymentinformation` and `.../incomplete?#`

**What it means:** Your account is created but **not fully activated** — either registration unfinished or on free plan with limitations. From your screenshots:

- Billing country: **Indonesia**
- Required: card number (Visa/Mastercard), expiry `BB/TT`, CVC, name on card
- Address on file: `Jln. Penggilingan RT01/RW08 No.255, DKI Jakarta ... 13940, ID`

**Fix:**

1. Enter a valid **credit or debit card** (AWS accepts most Visa/Mastercard; prepaid / virtual cards often rejected for the $1 verification hold).
2. Expect a **temporary $1 USD (or equivalent) authorization hold for 3–5 days** — this is verification only, not a charge. Approve it in your bank app if prompted.
3. Click **Lanjutkan (langkah 3 dari 5)** and complete all 5 steps: contact info → payment → identity verification (phone) → support plan → finish.
4. Check spam/junk for AWS verification emails.
5. Wait **up to 24 hours** for services to activate. EC2 in `ap-southeast-1` (Singapore) will fail to launch until activation completes.
6. To review/update later: Billing → **Payment Preferences**. To lift free-plan limits: **Upgrade plan**.
7. If activation stalls >24h: **contact support** link on the incomplete page (no card charge for free tier until you upgrade to paid).

---

## 3. EC2 launch checklist (from your "Membuat akun AWS dan Instance EC2" video)

What you did correctly in screenshots: `Amazon Linux 2023 kernel-6.18 AMI (ami-01a395a37625fb28c)`, `t3.micro`, `gp3 8 GiB`, security group, `test` key pair, `EC2 Instance Connect`, `i-09880b9a5a2b8bc86` running with public IP `13.214.194.43`.

- **Key pair dialog (Step 4/8):** Choose **Create new key pair** → name it → **RSA** (broadest compat) or **ED25519** (modern) → **.pem** for OpenSSH / **.ppk** for PuTTY → **Create** → download once, `chmod 400`. Use `scripts/manage-keypairs.sh` in this repo for CLI equivalent.
- **AMI:** Quick Start → Amazon Linux → `ami-01a395a37625fb28c (64-bit x86, uefi-preferred)`. Username is `ec2-user` (Ubuntu AMIs use `ubuntu`).
- **Connect:** Instances → `i-...` → Connect → EC2 Instance Connect → public IPv4 → Connect. Or `ssh -i test.pem ec2-user@<public-ip>`.
- **Cleanup:** Terminate `i-09880b9a5a2b8bc86` when done (you already did: "Successfully initiated termination") to avoid charges.

---

*Last updated: Oct 2026. Screenshots contain personal email/phone/address — redact before sharing publicly.*
