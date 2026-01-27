# 🚀 Quick Start - Deploy in 5 Minutes

## Step 1: Import Workflow (1 min)

```bash
# In n8n web interface:
1. Click "Workflows" → "Add Workflow"
2. Click "Import from File"
3. Select: improved_ai_operating_model_workflow.json
4. Click "Import"
```

## Step 2: Verify Credentials (2 min)

Check these credentials are configured:

- [ ] Google Drive OAuth2 (`HGcwinsAHvFxWc4L`)
- [ ] Google Sheets OAuth2 (`HSKZd2nGiLCRcvQ9`)
- [ ] Airtable Token API (`0Gdjq1yShsYU4A6D`)
- [ ] OpenAI API (`sHNKcTxbhPX7Z73K`)
- [ ] Supabase API (`LQrRbDHg28uKLFJW`)
- [ ] Slack OAuth2 (`y3BY0QNsUHy5B2Pf`)

## Step 3: Test Run (2 min)

```bash
1. Click "Execute Workflow"
2. Watch execution log (should complete in ~70 seconds)
3. Check outputs:
   ✅ Airtable record created
   ✅ Google Drive file uploaded
   ✅ Slack notification received
   ✅ Supabase patterns stored
```

## Step 4: Verify Results

### Check Airtable
https://airtable.com/appE3ZTIBGNCbQmPf/Client_Models

Should see new record with:
- Audit ID
- Client Name: "Hogarth Worldwide"
- ROI: ~650%
- Status: "Completed"

### Check Google Drive
https://drive.google.com/drive/folders/1ecFCQPJIxS7pwmswxfHvnLqGe3garKlb

Should see new file:
`Hogarth_Worldwide_AI_Operating_Model_[timestamp].txt`

### Check Slack
Channel: #general

Should see message:
"🎯 AI Operating Model Audit Complete"

## 🎉 You're Done!

The workflow is now production-ready.

## Next Steps

### For Hogarth Internal Audits:
- Run as-is (default config is for Hogarth)

### For Client Audits:
1. Update "Set Client Config" node
2. Change `client_name` to client name
3. Update Google Sheet IDs if needed
4. Run workflow

## Cost Tracking

- Each audit costs: ~$0.21
- Monthly budget (10 audits): ~$2.10
- Set OpenAI billing alert: $10/month

## Support

- Check execution logs for errors
- Review WORKFLOW_IMPROVEMENTS_GUIDE.md for details
- Common issues documented in troubleshooting section

---

**Happy Auditing! 🚀**
