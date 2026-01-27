# Google Sheets Setup Guide
## AI Operating Model Audit Workflow

This workflow uses **Google Sheets instead of Airtable** - perfect for enterprise customers!

---

## 📋 Required Google Sheets

You need **2 new Google Sheets** (in addition to your existing RACI and KPI sheets):

### **Sheet 1: Tools_Inventory**
### **Sheet 2: Client_Models**

---

## 🔧 Step-by-Step Setup

### **1. Create "Tools_Inventory" Sheet**

**Purpose:** Stores your client's tool inventory (replaces Airtable)

#### **Create the sheet:**
1. Go to [Google Sheets](https://sheets.google.com)
2. Create a new spreadsheet
3. Name it: **"Tools_Inventory"**
4. Copy this sheet ID from the URL (you'll need it later)

#### **Add these column headers (Row 1):**

| Client | ToolName | Purpose | UserCount | AnnualCost |
|--------|----------|---------|-----------|------------|
| | | | | |

#### **Example data:**

| Client | ToolName | Purpose | UserCount | AnnualCost |
|--------|----------|---------|-----------|------------|
| Hogarth Worldwide | Adobe Creative Cloud | Design & Creative | 150 | 120000 |
| Hogarth Worldwide | Asana | Project Management | 200 | 24000 |
| Hogarth Worldwide | Slack | Communication | 250 | 18000 |
| Hogarth Worldwide | Salesforce | CRM | 50 | 75000 |

#### **Column descriptions:**
- **Client**: Client name (e.g., "Hogarth Worldwide")
- **ToolName**: Name of the software/tool
- **Purpose**: What it's used for
- **UserCount**: Number of users
- **AnnualCost**: Annual cost in USD

---

### **2. Create "Client_Models" Sheet**

**Purpose:** Stores audit results (replaces Airtable Client_Models table)

#### **Create the sheet:**
1. Create another new spreadsheet
2. Name it: **"Client_Models"**
3. Copy this sheet ID from the URL

#### **Add these column headers (Row 1):**

| Audit_ID | Client_Name | Recommended_Scenario | ROI_3Year | Annual_Saving | Implementation_Cost | FTE_Saved | Executive_Summary | Status | Created_At |
|----------|-------------|---------------------|-----------|---------------|---------------------|-----------|-------------------|--------|------------|
| | | | | | | | | | |

#### **Column descriptions:**
- **Audit_ID**: Auto-generated unique ID
- **Client_Name**: Client name
- **Recommended_Scenario**: Usually "Hybrid"
- **ROI_3Year**: 3-year ROI percentage
- **Annual_Saving**: Annual cost savings in USD
- **Implementation_Cost**: Upfront implementation cost
- **FTE_Saved**: Number of FTEs saved
- **Executive_Summary**: First 5000 chars of report
- **Status**: "Completed" or "In Progress"
- **Created_At**: Timestamp

**Note:** This sheet will be **automatically populated** by the workflow. You don't need to add data manually.

---

## 🔗 Step 3: Get Sheet IDs

For each Google Sheet, you need the **Sheet ID** from the URL:

### **How to find Sheet ID:**

URL format:
```
https://docs.google.com/spreadsheets/d/SHEET_ID_HERE/edit#gid=0
                                      ^^^^^^^^^^^^^^^^
```

**Example:**
```
https://docs.google.com/spreadsheets/d/1XcggscF9iSF3saKBnM_CWmbGnr7Ls3qBjgKNBRgzp5M/edit
```
Sheet ID: `1XcggscF9iSF3saKBnM_CWmbGnr7Ls3qBjgKNBRgzp5M`

---

## ⚙️ Step 4: Update Workflow Configuration

In n8n, open the workflow and find the **"Set Client Config"** node.

Update these lines with your Sheet IDs:

```javascript
google_sheets_tools_id: "YOUR_TOOLS_INVENTORY_SHEET_ID",
google_sheets_results_id: "YOUR_CLIENT_MODELS_SHEET_ID",
```

**Replace:**
- `YOUR_TOOLS_INVENTORY_SHEET_ID` → Your Tools_Inventory sheet ID
- `YOUR_CLIENT_MODELS_SHEET_ID` → Your Client_Models sheet ID

---

## ✅ Step 5: Share Sheets with n8n

Make sure n8n can access your sheets:

1. Open each Google Sheet
2. Click **Share** (top right)
3. Add the **email address associated with your n8n Google Sheets credential**
4. Set permission to **Editor**
5. Click **Send**

---

## 🧪 Step 6: Test the Workflow

1. Add some test data to **Tools_Inventory** sheet
2. Run the workflow in n8n
3. Check that **Client_Models** sheet gets a new row with audit results

---

## 📊 Comparison: Airtable vs Google Sheets

| Feature | Airtable | Google Sheets |
|---------|----------|---------------|
| **Cost** | $20-45/month | **FREE** ✅ |
| **Setup** | Complex | Simple |
| **Enterprise** | Requires subscription | Built-in with Google Workspace |
| **Sharing** | Limited on free tier | Unlimited |
| **n8n Integration** | API calls | Native node |
| **Familiarity** | Learning curve | Everyone knows Sheets |

---

## 🎯 Benefits of Google Sheets Edition

✅ **No subscription costs** - 100% free
✅ **Easier for clients** - They already use Google Workspace
✅ **Better collaboration** - Built-in commenting, sharing
✅ **Version history** - Automatic versioning
✅ **Offline access** - Works offline with Google Drive
✅ **Simpler setup** - No API tokens, just OAuth

---

## 🔄 Migration from Airtable (If Needed)

If you have existing data in Airtable:

### **Export from Airtable:**
1. Open your Airtable base
2. Click on a table → **...** menu → **Download CSV**
3. Repeat for all tables

### **Import to Google Sheets:**
1. Open your new Google Sheet
2. **File** → **Import** → **Upload** → Select CSV
3. Choose **Replace current sheet** or **Append to current sheet**
4. Click **Import data**

---

## 📝 Template Sheets (Optional)

Want to save time? I can provide you with template Google Sheets you can copy:

### **Tools_Inventory Template:**
```
Client | ToolName | Purpose | UserCount | AnnualCost
Hogarth Worldwide | Adobe CC | Creative | 150 | 120000
Hogarth Worldwide | Asana | PM | 200 | 24000
Hogarth Worldwide | Slack | Comms | 250 | 18000
```

### **Client_Models Template:**
Headers only - workflow will populate automatically.

---

## 🆘 Troubleshooting

### **Error: "Could not find sheet"**
- Check that Sheet IDs are correct in "Set Client Config"
- Verify sheets are shared with n8n's Google account

### **Error: "Permission denied"**
- Share sheets with n8n Google Sheets credential email
- Set permission to "Editor" (not "Viewer")

### **No data appearing in Client_Models**
- Check workflow execution log
- Verify column names match exactly (case-sensitive)
- Check that "4.1 Write to Google Sheets" node executed

### **Tool Inventory not loading**
- Check that sheet name is exactly "Tools_Inventory"
- Verify data starts in Row 2 (Row 1 is headers)
- Check that Client name matches workflow config

---

## 🚀 Next Steps

1. ✅ Create the 2 Google Sheets
2. ✅ Add column headers
3. ✅ Add sample data to Tools_Inventory
4. ✅ Copy Sheet IDs
5. ✅ Update workflow config
6. ✅ Share sheets with n8n
7. ✅ Test the workflow

---

## 💡 Pro Tips

**For multiple clients:**
- Use same sheets, different rows
- Filter by Client column
- Use separate tabs for each client

**Data quality:**
- Add data validation to columns
- Use formulas for calculations
- Freeze header row for easier scrolling

**Backup:**
- Google Sheets auto-saves
- Access version history: **File** → **Version history**
- Download backups: **File** → **Download** → **CSV**

---

**Questions?** The workflow is ready to use with Google Sheets! 🎉
