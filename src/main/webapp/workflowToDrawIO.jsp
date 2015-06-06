<%--
 This utility page facilitates the conversion of the Salesforce workflow XML to the XML that Google's DrawIO package expects.

 To use this utility, follow these steps:
 1) download the workflow metadata from Salesforce using the SF_MetaData.jsp page
 2) unzip the file downloaded from Salesforce and navigate to the folder that holds the workflow XML
 3) open the workflow XML in the editor of your choice
 4) select all of the XML text and copy it to your clipboard
 5) paste the text into the top tex area that is displayed on this page
 6) click the "Convert" button
 7) the converted XML will show up in the lower text area
 8) if the Google Drive upload is enabled, click the "Upload" button to save the XML into your Google Drive
 9) if the Google Drive upload is not enabled, copy the text from the lower text area and paste it into a new file and
    upload that file to Google Drive

  This software is made available under the MIT License:

  Copyright (c) 2015 zPaper Inc.

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
--%>
<%@ page
        import="org.apache.log4j.*,java.util.Properties,org.apache.commons.lang.StringEscapeUtils"
        session="false"
%>
<%@ page import="javax.xml.parsers.DocumentBuilderFactory" %>
<%@ page import="javax.xml.parsers.DocumentBuilder" %>
<%@ page import="javax.xml.xpath.XPathFactory" %>
<%@ page import="javax.xml.xpath.XPath" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="org.w3c.dom.Document" %>
<%@ page import="org.w3c.dom.NodeList" %>
<%@ page import="javax.xml.xpath.XPathConstants" %>
<%@ page import="org.w3c.dom.Element" %>
<%@ page import="java.io.*" %>
<%@ page import="javax.xml.parsers.ParserConfigurationException" %>
<%@ page import="org.xml.sax.SAXException" %>
<%@ page import="javax.xml.xpath.XPathExpressionException" %>
<%!
    static Logger logger = Logger.getLogger("com.zpaper.zworks.workflowToDrawIO");

    private static final String DRAW_UI_OUTER_TAG_BEGIN = "<mxGraphModel dx=\"800\" dy=\"800\" grid=\"1\" guides=\"1\" tooltips=\"1\" " +
                                                          "connect=\"1\" fold=\"1\" page=\"1\" pageScale=\"1\" pageWidth=\"826\" " +
                                                          "pageHeight=\"1169\" style=\"default-style2\">";
    private static final String DRAW_UI_OUTER_TAG_END = "</mxGraphModel>";
    private static final String DRAW_UI_ROOT_TAG_BEGIN = "<root>";
    private static final String DRAW_UI_ROOT_TAG_END = "</root>";
    private static final String DRAW_UI_MXCELL_TAG_BEGIN = "<mxCell id=\"";
    private static final String DRAW_UI_MXCELL_TAG_END = "</mxCell>";
    private static final String DRAW_UI_MXCELL_0_TAG = "<mxCell id=\"0\"/>";
    private static final String DRAW_UI_GEOMETRY_TAG_BEGIN = "<mxGeometry ";
    private static final String DRAW_UI_GEOMETRY_TAG_END = "</mxGeometry>";
    private static final String DRAW_UI_CR = "&#xa;";                      // carriage return

    class Action {
        private String name;
        private String type;

        public Action(final String name, final String type) {
            this.name = name;
            this.type = type;
        }

        public String getName() {
            return name;
        }

        public String getType() {
            return type;
        }
    }

    class TimeTrigger {
        String timeLength;
        String triggerUnit;
        List<Action> actions;

        public TimeTrigger(final String timeLength, final String triggerUnit) {
            this.timeLength = timeLength;
            this.triggerUnit = triggerUnit;
            actions = new ArrayList<Action>();
        }

        public void addAction(Action action) {
            actions.add(action);
        }

        public String getTimeLength() {
            return timeLength;
        }

        public String getTriggerUnit() {
            return triggerUnit;
        }

        public List<Action> getActions() {
            return actions;
        }
    }

    class CriteriaItem {
        String field;
        String operation;
        String value;

        public CriteriaItem(String field, String operation, String value) {
            this.field = field;
            this.operation = operation;
            this.value = value;
        }

        public String getField() {
            return field;
        }

        public String getOperation() {
            return operation;
        }

        public String getValue() {
            return value;
        }
    }

        String cells = "", lines = "";
        int c = 0, line = 0;
        Properties alerts = null, updates = null, messages = null, lineLabels = null; //ERS130420 NOT THREAD SAFE?
        String BR = "<BR>", sftype0 = "";

    class Rule {
        String fullName;
        boolean isActive;
        String description;
        List<Action> actions;
        String criteriaLogic;                   // e.g. 1 AND 2 AND 3 AND (4 OR 5)
        List<CriteriaItem> criteriaItems;
        String formula;
        String triggerType;
        List<TimeTrigger> timeTriggers;
        public String id, trigger, action, sftype;
        public int x, y;

        public Rule(String fullName) {
            fullName = fullName.replaceAll("%3A", ":");
            this.fullName = fullName;
            id = fullName.substring(2 + fullName.indexOf(":")).replaceAll(" ", "_") + "_Rule";
            actions = new ArrayList<Action>();
            criteriaItems = new ArrayList<CriteriaItem>();
            timeTriggers = new ArrayList<TimeTrigger>();
            trigger = ""; action = ""; sftype = "";
            x = 15; y = 15;
        }

        public String getFullName() {
            return fullName; //ERS.unscape();
        }

        public boolean isActive() {
            return isActive;
        }

        public void setActive(boolean active) {
            isActive = active;
        }

        public String getDescription() {
            return description;
        }

        public void setDescription(String description) {
            this.description = description;
        }

        public List<Action> getActions() {
            return actions;
        }

        public void addAction(Action action) {
            this.actions.add(action);
        }

        public String getCriteriaLogic() {
            return criteriaLogic;
        }

        public void setCriteriaLogic(String criteriaLogic) {
            this.criteriaLogic = criteriaLogic;
        }

        public List<CriteriaItem> getCriteriaItems() {
            return criteriaItems;
        }

        public void addCriteriaItem(CriteriaItem criteriaItem) {
            this.criteriaItems.add(criteriaItem);
        }

        public String getFormula() {
            return formula;
        }

        public void setFormula(final String formula) {
            this.formula = formula;
        }

        public String getTriggerType() {
            return triggerType;
        }

        public void setTriggerType(String triggerType) {
            this.triggerType = triggerType;
        }

        public List<TimeTrigger> getTimeTriggers() {
            return timeTriggers;
        }

        public void addTimeTrigger(TimeTrigger timeTrigger) {
            this.timeTriggers.add(timeTrigger);
        }

        //Alert shape=message with receipents, ccEmails, and template
        //field shape=mxgraph.flowchart.data (name) and connection with field update
        //Message ellipse;shape=cloud
        public String buildAction(Rule r, String name, String type, String connectionLabel, Element node) {
            String rs = "";
            String s = "shape=mxgraph.flowchart.data"; //update field
            String id = name.replaceAll(" ", "_") + "_" + type + "";
            String v = name;
            String a = "";

            int xx = r.x + 450, yy = r.y; //0+(c+1)*70;
            String bg = ""; if (!r.isActive && 1 == 0) bg = ";fillColor=#E6E6E6";
            if (!r.isActive && 1 == 1) bg = ";dashed=1";
            String stroke = "strokeColor=#005BB8;";
            if (connectionLabel.indexOf("after") > -1) stroke = "strokeColor=#00BB00;";
            if ("OutboundMessage".equals(type)) { //outbound message
                s = "ellipse;shape=cloud";
                a = messages.getProperty(id);
                if (a != null && !"".equals(a)) v += BR + a;
            }
            else if ("Alert".equals(type)) { //alert
                s = "shape=message";
                //s="swimlane";
                a = alerts.getProperty(id);
                if (a != null && !"".equals(a)) connectionLabel += BR + a;
            } //alert
            else if ("FieldUpdate".equals(type)) {
                a = updates.getProperty(id);
                if (a != null && !"".equals(a)) connectionLabel += BR + a;
                id = r.sftype + "_UpdateRecord"; s = "shape=mxgraph.flowchart.data";
                xx = xx + 350;
                v = r.sftype;
            } //ERS130420 TODO find sftype?
            else logger.error("UNKNOWN Action " + name + " has id " + id + " and type='" + type + "'");
            //s+=bg;
            if (cells.indexOf("," + id + ",") == -1) {
                rs += "<mxCell id=\"" + id + "\" value=\"" + v + "\" style=\"" + s + "\" vertex=\"1\" parent=\"1\">\n"
                      + "<mxGeometry x=\"" + xx + "\" y=\"" + yy + "\" width=\"250\" height=\"80\" as=\"geometry\" />\n"
                      + "</mxCell>\n";
                cells += "," + id + ","; c++;
            }
            else logger.debug("ALREADY MADE " + id);
            String thisLine = "," + r.id + ":" + id + ",";

            if (lines.indexOf(thisLine) == -1 && !"FieldUpdate".equals(type)) {
                logger.debug(">>>> writing connectionLabel: " + connectionLabel);
                rs += ("<mxCell id=\"" + id + "Action" + line + "\" value=\"" + connectionLabel + "\" " +
                       "style=\"endArrow=classic;exitX=1;exitY=0.5;" + stroke + "labelBackgroundColor=none;edgeStyle=entityRelationEdgeStyle" + bg + "\" " +
                       "edge=\"2\" parent=\"1\" source=\"" + r.id + "\" target=\"" + id + "\">\n" +
                       "<mxGeometry relative=\"1\" as=\"geometry\" />\n</mxCell>\n");
                line++;
                lines += thisLine;
            }
            else {
                String thisId = r.id + ":" + id;
                a = lineLabels.getProperty(thisId);
                if (a != null && !"".equals(a)) connectionLabel += a;
                lineLabels.setProperty(thisId, connectionLabel);
                logger.debug(">>>> writing connectionLabel for fldUpdate: " + connectionLabel);
                rs += ("<mxCell id=\"" + thisId + "_Action\" value=\"" + connectionLabel + "\" " +
                       "style=\"endArrow=classic;exitX=1;exitY=0.5;strokeColor=#005BB8;labelBackgroundColor=none;edgeStyle=entityRelationEdgeStyle" + bg + "\" " +
                       "edge=\"2\" parent=\"1\" source=\"" + r.id + "\" target=\"" + id + "\">\n" +
                       "<mxGeometry relative=\"1\" as=\"geometry\" />\n</mxCell>\n");
            }
            return rs;
        }
    }

%><%
    String xmlToConvert = request.getParameter("workflowXML");
    logger.debug("@@@@@@@@@@@ xmlToConvert @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    logger.debug(xmlToConvert);
    logger.debug("@@@@@@@@@@@ xmlToConvert -END @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    String convertedXML = "";
    //String cells="";
    //int c=0;
    if (null != xmlToConvert && xmlToConvert.length() > 0) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            DocumentBuilder builder = factory.newDocumentBuilder();
            XPathFactory xPathFactory = XPathFactory.newInstance();
            XPath xpath = xPathFactory.newXPath();
            cells = ""; lines = "";

            List<Rule> rules = new ArrayList<Rule>();
            Document workflowDoc = builder.parse(new ByteArrayInputStream(xmlToConvert.getBytes()));
            String cell0 = "", recordType = "";

            NodeList workflowAlerts = (NodeList)xpath.evaluate("/Workflow/alerts", workflowDoc, XPathConstants.NODESET);
            alerts = new Properties();
            for (int i = 0, alertsLimit = workflowAlerts.getLength(); i < alertsLimit; i++) {
                //hashmap of alerts by id with values stored
                Element workflowItem = (Element)workflowAlerts.item(i);
                String id = xpath.evaluate("fullName", workflowItem) + "_Alert";
                String v = BR + "Template: " + xpath.evaluate("template", workflowItem);
                NodeList workflowItems = (NodeList)xpath.evaluate("recipients", workflowItem, XPathConstants.NODESET);
                for (int i2 = 0; i2 < workflowItems.getLength(); i2++) {
                    v += BR + " To: " + xpath.evaluate("field", workflowItems.item(i2)) + xpath
                            .evaluate("recipient", workflowItems.item(i2));
                }
                v += BR + "CC: " + xpath.evaluate("ccEmails", workflowItem);
                String v0 = alerts.getProperty(id); if (v0 != null) v = v0 + BR + v;
                alerts.setProperty(id, v);
            }

            NodeList workflowUpdates = (NodeList)xpath
                    .evaluate("/Workflow/fieldUpdates", workflowDoc, XPathConstants.NODESET);
            updates = new Properties();
            lineLabels = new Properties();
            for (int i = 0, alertsLimit = workflowUpdates.getLength(); i < alertsLimit; i++) {
                //hashmap of alerts by id with values stored
                Element workflowItem = (Element)workflowUpdates.item(i);
                String id = xpath.evaluate("fullName", workflowItem) + "_FieldUpdate";
                //StringEscapeUtils.escapeHtml()
                String f = xpath.evaluate("formula", workflowUpdates.item(i)).replaceAll("&", " and ")
                                .replaceAll("\"", "");
                String literal = xpath.evaluate("literalValue", workflowUpdates.item(i));
                if (literal.length() > 0) f = literal;
                //CRN150602 fix drawIO rendering problem: it doesn't like tags inside strings either - escape tag delimiters.
                f = f.replace("<", StringEscapeUtils.escapeHtml("&lt;")).replace(">", StringEscapeUtils.escapeHtml("&gt;"));
                String v = xpath.evaluate("field", workflowUpdates.item(i)) + " = '" + f + "'";
                //if (f.length() > 40) v=xpath.evaluate("field", workflowUpdates.item(i)) + " = '"+"FORMULA!"+"'";
                String v0 = updates.getProperty(id); if (v0 != null) v = v0 + BR + v;
                updates.setProperty(id, v);
                logger.debug("updates(" + id + ")=" + v);
            }

            NodeList workflowMsgs = (NodeList)xpath
                    .evaluate("/Workflow/outboundMessages", workflowDoc, XPathConstants.NODESET);
            messages = new Properties();
            for (int i = 0, alertsLimit = workflowMsgs.getLength(); i < alertsLimit; i++) {
                //hashmap of alerts by id with values stored
                Element workflowItem = (Element)workflowMsgs.item(i);
                String id = xpath.evaluate("fullName", workflowItem) + "_OutboundMessage";
                String v = xpath.evaluate("endpointUrl", workflowItem);
                v += BR + " with " + xpath.evaluate("fields", workflowItem);
                String v0 = messages.getProperty(id); if (v0 != null) v = v0 + BR + v;
                messages.setProperty(id, v);
            }

            int xCoordinate = 275;  //was 5      // these should really be floats but for now we'll just deal with ints
            int yCoordinate = 55;  //was 5

            NodeList workflowRules = (NodeList)xpath.evaluate("/Workflow/rules", workflowDoc, XPathConstants.NODESET);
            for (int i = 0, rulesLimit = workflowRules.getLength(); i < rulesLimit; i++) {
                Element workflowRule = (Element)workflowRules.item(i);
                Rule rule = new Rule(xpath.evaluate("fullName", workflowRule));
                rules.add(rule);
                rule.x = xCoordinate + 20 * rulesLimit; rule.y = yCoordinate + (i + 1) * 130;
                //rule.setDescription(xpath.evaluate("description", workflowRule));
                rule.setTriggerType(xpath.evaluate("triggerType", workflowRule));                   // e.g. onCreateOrTriggeringUpdate
                rule.setActive(Boolean.parseBoolean(xpath.evaluate("active", workflowRule)));
                rule.setCriteriaLogic(xpath.evaluate("booleanFilter", workflowRule));               // e.g. 1 AND 2 AND 3 AND (4 OR 5)

                NodeList criteriaItems = (NodeList)xpath
                        .evaluate("criteriaItems", workflowRule, XPathConstants.NODESET);
                for (int j = 0, criteriaLimit = criteriaItems.getLength(); j < criteriaLimit; j++) {
                    Element item = (Element)criteriaItems.item(j);
                    if (i == 0 && j == 0) { //infer the record type from the fullName
                        int y0 = 70 * rulesLimit;
                        recordType = xpath.evaluate("field", item);
                        recordType = recordType.substring(0, recordType.indexOf(".") - 0);
                        cell0 = "<mxCell id=\"1\" parent=\"0\" />\n";
                        cell0 += "<mxCell id=\"" + recordType + "_Record\" value=\"" + recordType + "\" style=\"shape=mxgraph.flowchart.data;fontSize=14;strokeWidth=2;\" vertex=\"1\" parent=\"1\">\n"
                                 + "<mxGeometry x=\"5\" y=\"" + y0 + "\" width=\"120\" height=\"50\" as=\"geometry\" />\n"
                                 + "</mxCell>\n";
                        cells += "," + recordType + "_Record,"; c++;
                    }
                    CriteriaItem criteria = new CriteriaItem(xpath.evaluate("field", item),
                                                             xpath.evaluate("operation", item),
                                                             xpath.evaluate("value", item));
                    rule.addCriteriaItem(criteria);
                    rule.trigger += BR + criteria.getField() + " " + criteria.getOperation() + " '" + criteria
                            .getValue() + "'"; //&#xa;\n";
                    //rule.trigger=criteria.getField()+" "+criteria.getOperation()+" '"+criteria.getValue()+"'&#xa;\n"; //ERS TEST
                }
                sftype0 = rule.sftype = recordType;
                if (rule.getCriteriaLogic().indexOf("2") > -1)
                    rule.trigger += BR + " with " + rule.getCriteriaLogic();// + "&#xa;\n";
                NodeList actionNodes = (NodeList)xpath.evaluate("actions", workflowRule, XPathConstants.NODESET);
                String n = "", t = "";
                for (int j = 0, actionsLimit = actionNodes.getLength(); j < actionsLimit; j++) {
                    Element actionNode = (Element)actionNodes.item(j);
                    n = xpath.evaluate("name", actionNode);
                    t = xpath.evaluate("type", actionNode);
                    rule.addAction(new Action(n, t));
                    rule.action += rule.buildAction(rule, n, t, "", actionNode);
                }
                NodeList delayedTriggers = (NodeList)xpath
                        .evaluate("workflowTimeTriggers", workflowRule, XPathConstants.NODESET);
                for (int j = 0, triggersLimit = delayedTriggers.getLength(); j < triggersLimit; j++) {
                    Element item = (Element)delayedTriggers.item(j);
                    String timeLength = xpath.evaluate("timeLength", item);
                    String workflowTimeTriggerUnit = xpath.evaluate("workflowTimeTriggerUnit", item);
                    TimeTrigger timeTrigger = new TimeTrigger(timeLength, workflowTimeTriggerUnit);
                    NodeList delayedActions = (NodeList)xpath.evaluate("actions", item, XPathConstants.NODESET);
                    for (int k = 0, actionsLimit = delayedActions.getLength(); k < actionsLimit; k++) {
                        Element delayedAction = (Element)delayedActions.item(k);
                        n = xpath.evaluate("name", delayedAction);
                        t = xpath.evaluate("type", delayedAction);
                        timeTrigger.addAction(new Action(n, t));
                        //same as actions but with time info on connector
                        rule.action += rule
                                .buildAction(rule, n, t, " after " + timeLength + " " + workflowTimeTriggerUnit, delayedAction);
                    }
                    rule.addTimeTrigger(timeTrigger);
                }
            }
            // Now that we have a list of Rule objects, generate the draw xml.
            StringWriter strWriter = new StringWriter();
            PrintWriter writer = new PrintWriter(strWriter);
            writer.println(DRAW_UI_OUTER_TAG_BEGIN);
            writer.println(DRAW_UI_ROOT_TAG_BEGIN);
            writer.println(DRAW_UI_MXCELL_0_TAG);

            int curId = 3;  //was 1

            StringBuilder buffer = new StringBuilder();
            buffer.append(cell0);
            int rulesLimit = workflowRules.getLength();
            int i = 1;
            for (Rule rule : rules) {
                logger.debug("Writing rule to buffer");
                curId++; cells += "," + rule.id + ","; c++;
                xCoordinate = rule.x; yCoordinate = rule.y;
                String bg = ""; if (!rule.isActive) bg = ";fillColor=#E6E6E6";
                buffer.append(DRAW_UI_MXCELL_TAG_BEGIN).append(rule.id + "\" "); //append(curId++) not needed
                buffer.append("value=\"").append(rule.getFullName());
                if (null != rule.getDescription()) { buffer.append(DRAW_UI_CR).append(rule.getDescription()); }
                buffer.append("\" ")
                      .append("style=\"shape=mxgraph.flowchart.paper_tape;whiteSpace=wrap;fontStyle=0" + bg + "\" parent=\"1\" vertex=\"1\">")
                      .append('\n');
                buffer.append(DRAW_UI_GEOMETRY_TAG_BEGIN).append("x=\"").append(xCoordinate).append("\" ");
                buffer.append("y=\"").append(yCoordinate).append("\" ");
                buffer.append("width=\"200\" height=\"120\" as=\"geometry\"/>").append('\n');
                buffer.append(DRAW_UI_MXCELL_TAG_END).append('\n');
                curId++;
                String exit = "";
                String edge = "edgeStyle=entityRelationEdgeStyle;"; //was "edgeStyle=elbowEdgeStyle;elbow=horizontal;"
                if (i < rulesLimit / 3) exit = "exitX=0.5;exitY=0.0;" + edge;
                else if (i > 2 * rulesLimit / 3) exit = "exitX=0.5;exitY=1.0;" + edge;
                else exit = "exitX=0.905;exitY=0.5;" + edge;
                //create a connector from recordTypeRecord to new cell
                buffer.append("<mxCell id=\"" + rule.id + "_Trigger\" value=\"" + rule.trigger + "\" " +
                              "style=\"endArrow=classic;" + exit + "strokeColor=#005BB8;labelBackgroundColor=none;\"" +
                              " edge=\"2\" parent=\"1\" source=\"" + recordType + "_Record\" target=\"" + rule.id + "\">\n" +
                              "<mxGeometry relative=\"1\" as=\"geometry\" />\n</mxCell>\n");
                buffer.append(rule.action);
                i++;
            }
            writer.print(buffer);

            writer.println(DRAW_UI_ROOT_TAG_END);
            writer.println(DRAW_UI_OUTER_TAG_END);
            writer.flush();
            convertedXML = strWriter.toString();
        }
        catch (ParserConfigurationException e) {
            convertedXML = "ERROR: " + e;
            logger.error(convertedXML, e);
        }
        catch (SAXException e) {
            convertedXML = "ERROR: " + e;
            logger.error(convertedXML, e);
        }
        catch (IOException e) {
            convertedXML = "ERROR: " + e;
            logger.error(convertedXML, e);
        }
        catch (XPathExpressionException e) {
            convertedXML = "ERROR: " + e;
            logger.error(convertedXML, e);
        }
    }
    else {
        xmlToConvert = "";
    }
%>
<html>
<head>
    <title>Convert Workflow XML file into DrawIO-Compatible XML</title>
    <link href="./css/jquery-ui-1.10.3.custom.min.css" media="all" rel="stylesheet" type="text/css"/>
    <script type="text/javascript" src="./js/jquery-1.10.2.min.js"></script>
    <script type="text/javascript" src="./js/jquery-ui-1.10.3.custom.min.js"></script>
    <script type="text/javascript">
        function uploadToDrive() {
            var $dialog = $('#dlg-fileName-prompt').dialog({
                autoOpen: true,
                minWidth: 600,
                minHeight: 400,
                modal: true,
                buttons: {
                    "OK": function () {
                        var form = document.getElementById("drawIOForm");
                        if (form) {
                            var drawIOFName = $('#dlg-fileName').val();
                            if (!drawIOFName || 0 == drawIOFName.length) {
                                alert("Please enter the file name.");
                                return;
                            }
                            form.action = "uploadToDrive.jsp";
                            $('#fileName').val(drawIOFName);
                            form.submit();
                        }
                    },
                    Cancel: function () {
                        $dialog.dialog("close");
                    }
                }
            });
        }
    </script>
</head>
<body style="text-align:center;">
<form id="drawIOForm" action="workflowToDrawIO.jsp" method="POST">
    <input type="hidden" id="fileName" name="fileName">

    <h2>Convert Salesforce Workflow XML to DrawIO-Compatible XML</h2>

    <div style="width:100%;text-align:center;">
        <p style="font-weight:bold;">
            Paste XML here from workflow:
        </p>

        <p>
            <textarea id="workflowXML" name="workflowXML" rows="12" cols="80"
                      style="width:90%;"><%=xmlToConvert%></textarea>
            <br/>
            <input type="submit" value="Convert" style="width:120px;">
        </p>

        <p style="padding-top:12px;font-weight:bold;">
            DrawIO XML will be converted to here:
        </p>

        <p>
            <textarea id="drawioXML" name="drawioXML" rows="12" cols="80"
                  style="width:90%;"><%=convertedXML.replace(BR, StringEscapeUtils.escapeHtml("&#xa;"))
                                                    .replace(sftype0 + "\\.", "")
                                                    .replace("(?i)" + sftype0.replace("__c", "") + "s: ", "")
                                                    .replace("%22", "'")%></textarea>
            <br/>
            <input type="button" value="Upload XML to Google Drive" onclick="uploadToDrive();"/>
        </p>
    </div>
</form>
<div id="dlg-fileName-prompt" title="Create New Question" style="display:none;">
    <div>
        <table style="width:100%;">
            <tr>
                <td colspan="99" style="padding-bottom:12px;font-weight:bold;">
                    Please enter the file name that will be used to save the DrawIO xml into Google Drive. <br/><br/>Note:
                    Any currently-existing file in your Google Drive with the same name will NOT be over-written. A
                    second file with the same name will instead be created.
                </td>
            </tr>
            <tr>
                <td style="text-align:right;padding-right:4px;white-space:nowrap;">
                    Save into File:
                </td>
                <td style="text-align:left;padding-left:4px;">
                    <input type="text" style="width:300px;" id="dlg-fileName"/>
                </td>
            </tr>
        </table>
    </div>
</div>
</body>
</html>