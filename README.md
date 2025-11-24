# SetupAuditTrail Package Generator  
_A Salesforce Implementation for Automated package.xml Creation Based on Setup Audit Trail Activity_

## 📌 Overview
This project is a complete Salesforce DX implementation that analyzes **SetupAuditTrail** records, extracts changed metadata components, and automatically generates a valid **package.xml** file for deployment.

It fulfills the problem statement and requirements outlined in the Senior Salesforce Developer Take-Home Assignment.

---

# 🚀 Features

### ✅ 1. Display Setup Audit Trail Data
- Fetches recent SetupAuditTrail entries (Apex)
- Supports filtering by:
  - Date range
  - Section (Apex Classes, Flows, Custom Objects, etc.)
  - Keyword found in Display text
- Supports pagination & scrolling (LWC)

### ✅ 2. Extract Component Information
- Parses SetupAuditTrail `"Display"` text using a custom parser
- Detects:
  - Apex classes  
  - Flows  
  - Custom objects  
  - Custom fields  
  - Any token matching metadata patterns
- Maps sections → Salesforce metadata types

### ✅ 3. Generate package.xml
- Groups metadata by type
- Sorts and deduplicates members
- Produces compliant Metadata API XML format
- Supports user-selected API version

---

# 🧱 Architecture
