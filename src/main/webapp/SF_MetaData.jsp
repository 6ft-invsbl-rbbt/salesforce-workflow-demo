<%--
  Retrieves the Salesforce Package Metadata Information given the SalesForce.com username, password and package name.

  If no parameters (or not enough parameters) are passed in, a form is displayed to the user that will allow the user to
  input their username, password, and package name to download. The user can also choose whether the Salesforce org is
  production or test (sandbox).

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
<%@ page session="false"
 import="com.sforce.soap.metadata.*,
         com.sforce.soap.partner.PartnerConnection,
         com.sforce.ws.ConnectionException,
         com.sforce.ws.ConnectorConfig,
         org.apache.log4j.Logger,
         java.util.Arrays,
         java.util.HashSet,
         java.util.Set"
%><%!

    private void pullPackage(final String sfServer,
                             final String userName,
                             final String password,
                             final String pkgName,
                             final HttpServletRequest request, final HttpServletResponse response) throws Exception {
        MetadataConnection metadataConnection = createMetadataConnection(sfServer, userName, password);

        // For an (unsatisfactory) explanation of the following line : http://www.salesforce.com/developer/tn-18.jsp
        response.setHeader("P3P", "CP=\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\"");
        response.setHeader("Content-Transfer-Encoding", "binary");
        response.setContentType("application/zip");
        boolean isIE = false;
        String browser = request.getHeader("User-Agent").toLowerCase();
        if (browser.contains("msie")) isIE = true;

        if (isIE)
            response.addHeader("Accept-Ranges", "none");
        response.addHeader("Expires", "0");
        response.addHeader("Pragma", "cache");
        response.addHeader("Cache-Control", "private");

        RetrieveRequest retrieveRequest = new RetrieveRequest();
        retrieveRequest.setSinglePackage(true);
        logger.debug("Retrieving MetaData in a Package: " + pkgName);
        retrieveRequest.setPackageNames(new String[]{pkgName});
        double apiVersion = 29.0;
        retrieveRequest.setApiVersion(apiVersion);
        logger.info("#### apiVersion that we have set into retrieve request: " + retrieveRequest.getApiVersion());

        logger.info("Sending retrieve request...");
        AsyncResult asyncResult = metadataConnection.retrieve(retrieveRequest);
        // wait for retrieve to complete...
        int pollCount = 0;
        long waitTimeMills = ONE_SECOND;
        long elapsedTime = 0;
        AsyncResult retrieveResult;
        do {
            logger.info("Waiting for async request to complete, count = " + pollCount + ", state = " + asyncResult
                    .getState() + ", waiting = " + waitTimeMills + ", elapsed time = " + elapsedTime);
            try {
                Thread.sleep(waitTimeMills);
            }
            catch (InterruptedException e) {
                // don't care
            }
            if (pollCount++ > MAX_POLL_REQUESTS) {
                throw new Exception("Request timed out. If this is a large set of metadata components, check that the time allowed by MAX_POLL_REQUESTS is sufficient");
            }
            elapsedTime += waitTimeMills;
            if (waitTimeMills < 32000) {
                waitTimeMills *= 2;     // double the wait time for the next iteration
            }
            // poll the connection to see if the request is complete yet (retrieveResult should never be null)
            retrieveResult = metadataConnection.checkStatus(new String[]{asyncResult.getId()})[0];
            logger.info("Retrieve request is done?  " + retrieveResult.getDone());
        }
        while (!retrieveResult.isDone());
        logger.info("Retrieve request was complete. Pulling zip file");
        if (retrieveResult.getState() != AsyncRequestState.Completed) {
            throw new Exception(asyncResult.getStatusCode() + " msg: " + retrieveResult.getMessage());
        }
        RetrieveResult result = metadataConnection.checkRetrieveStatus(retrieveResult.getId());
        // Print out any warning messages
        StringBuilder buf = new StringBuilder();
        if (result.getMessages() != null) {
            for (RetrieveMessage rm : result.getMessages()) {
                buf.append(rm.getFileName()).append(" - ").append(rm.getProblem());
            }
        }
        if (buf.length() > 0) {
            logger.warn("Retrieve warnings:\n" + buf);
        }

        // Write the zip to the response
        response.setHeader("Content-Disposition", "attachment; filename=\"" + pkgName
                .replaceAll(" ", "") + "PackageMetadata.zip\""); //ERS130419 added pkgName
        logger.info("Writing results to zip file");
        response.setContentType("application/zip"); //ERS140115 trying to make sfgw.jsp happy
        byte[] zipContents = result.getZipFile();
        logger.info("Size of zip file = " + zipContents.length);
        response.setContentLength(zipContents.length);
        ServletOutputStream out2 = response.getOutputStream();
        out2.write(zipContents);
        out2.flush();
    }

    public static final Logger logger = Logger.getLogger("com.zpaper.zworks.SF_MetaData");

    private static final long ONE_SECOND = 1000;
    private static final int MAX_POLL_REQUESTS = 120;

    // we only support this request for now
    private static final String OP_PULL_PACKAGE = "getPkg";
    // using latest API endpoint
    private static final String SF_LATEST_ENDPOINT = "services/Soap/u/29.0";

    private MetadataConnection createMetadataConnection(String sfServer, String userName, String password) throws
                                                                                                           ConnectionException {
        logger.info("@@@@@ 123 @@@@@");
        ConnectorConfig partnerConfig = new ConnectorConfig();
        ConnectorConfig metadataConfig = new ConnectorConfig();
        partnerConfig.setAuthEndpoint(sfServer + SF_LATEST_ENDPOINT);
        partnerConfig.setServiceEndpoint(sfServer + SF_LATEST_ENDPOINT);
        partnerConfig.setUsername(userName);
        partnerConfig.setPassword(password);
        logger.info("#### Authenticating #####");
        logger.info("Authenticating to Salesforce: endpoint=" + sfServer + ", user=" + userName);
        PartnerConnection partnerConnection = com.sforce.soap.partner.Connector.newConnection(partnerConfig);
        logger.info("@@@ Auth endpoint = " + partnerConfig.getAuthEndpoint());
        logger.info("@@@ Svc endpoint = " + partnerConfig.getServiceEndpoint());
        logger.info("$$$$$$ 134 $$$$$$$$$");
        // set the session id from the authenticated connection
        logger.info("@@@@ Session ID: " + partnerConnection.getSessionHeader().getSessionId());
        metadataConfig.setSessionId(partnerConnection.getSessionHeader().getSessionId());
        metadataConfig.setServiceEndpoint(partnerConfig.getServiceEndpoint().replace("/u/", "/m/"));
        logger.info("#### partnerConfig config auth session Id = " + partnerConfig.getSessionId());
        logger.info("#### partnerConfig config auth endpoint = " + partnerConfig.getAuthEndpoint());
        logger.info("#### partnerConfig config svc endpoint = " + partnerConfig.getServiceEndpoint());
        MetadataConnection metadataConnection = new MetadataConnection(metadataConfig);
        logger.info("#### MetaData config auth endpoint = " + metadataConfig.getAuthEndpoint());
        logger.info("#### MetaData config svc endpoint = " + metadataConfig.getServiceEndpoint());
        logger.info("#### MetaData config sfId = " + metadataConfig.getSessionId());
        logger.info("##### MetaData Connection sfId = " + metadataConnection.getSessionHeader().getSessionId());
        return metadataConnection;
    }

%><%
    String errorMsg = null;
    String userName = request.getParameter("un");
    String password = request.getParameter("pw");
    String pkgName = request.getParameter("pkgName");
    String sfServer = request.getParameter("SFserver");

    // Validate parameters
    String[] reqParms = new String[]{"un", "pw", "pkgName", "sfServer"};
    Set<String> requiredParameters = new HashSet<String>(Arrays.asList(reqParms));
    if (userName != null && userName.length() > 0 && !userName.equals("null")) requiredParameters.remove("un");
    if (password != null && password.length() > 0 && !password.equals("null")) requiredParameters.remove("pw");
    if (pkgName != null && pkgName.length() > 0 && !pkgName.equals("null")) requiredParameters.remove("pkgName");
    if (sfServer != null && sfServer.length() > 0 && !sfServer.equals("null")) requiredParameters.remove("sfServer");

    if (0 == requiredParameters.size()) {
        try {
            // ignoring the op parameter - we will only pull packages
            pullPackage(sfServer, userName, password, pkgName, request, response);
            return; // the pullPackage set the correct content type and content to return to user - so return here (don't show html form)
        }
        catch (Exception e) {
            logger.error("Exception pulling package: " + e, e);
            errorMsg = "Error downloading metadata: " + e;
        }
    }
    else if (requiredParameters.size() < reqParms.length) {
        // If some of the parameters were supplied, let the user know that parameters are missing. Otherwise, this
        // is just a request for the page so no need to bug the user.
        errorMsg = "Error: all fields below must be filled in";
    }
%>
<html>
<head>
    <title>Salesforce MetaData</title>
    <script> <%-- Google Analytics --%>
      (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
      (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
      m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
      })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

      ga('create', 'UA-63720203-1', 'auto');
      ga('send', 'pageview');
    </script>

</head>
<body style="text-align:center;">
<div id="errorDiv" style="color:red;font-weight:bold;">
    <%=null != errorMsg ? errorMsg : ""%>
</div>
<h3>Please enter the Username and Password (with security token tacked onto end) of the Salesforce server that you want
    to pull metadata from:</h3>

<p>

<form action="SF_MetaData.jsp" method="POST">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td style="width:44%;text-align:right;padding-right:4px;padding-top:4px;">Username:</td>
            <td style="width:56%;text-align:left;padding-left:4px;padding-top:4px;">
                <input style="width:280px;" type="text" name="un" value="<%=null != userName ? userName : ""%>"></td>
        </tr>
        <tr>
            <td style="width:44%;text-align:right;padding-right:4px;padding-top:4px;">Password:</td>
            <td style="width:56%;text-align:left;padding-left:4px;padding-top:4px;">
                <input style="width:280px;" type="password" name="pw" value="<%=null != password ? password : ""%>">
            </td>
        </tr>
        <tr>
            <td style="width:44%;text-align:right;padding-right:4px;padding-top:4px;">Salesforce Server:</td>
            <td style="width:56%;text-align:left;padding-left:4px;padding-top:4px;">
                <select name="SFserver" style="width:280px;">
                    <option value="https://login.salesforce.com/">Production</option>
                    <option value="https://test.salesforce.com/">Sandbox</option>
                </select>
            </td>
        </tr>
        <tr>
            <td style="width:44%;text-align:right;padding-right:4px;padding-top:4px;">Requested Operation:</td>
            <td style="width:56%;text-align:left;padding-left:4px;padding-top:4px;">
                <select name="op" style="width:280px;">
                    <option value="<%=OP_PULL_PACKAGE%>">Download Package</option>
                </select>
            </td>
        </tr>
        <tr>
            <td style="width:44%;text-align:right;padding-right:4px;padding-top:4px;">Package Name:</td>
            <td style="width:56%;text-align:left;padding-left:4px;padding-top:4px;">
                <input style="width:280px;" type="text" name="pkgName" value="<%=null != pkgName ? pkgName : ""%>">
            </td>
        </tr>
        <tr>
            <td style="text-align:center;padding-top:16px;" colspan="2">
                <input type="submit" style="width:80px;" value="Go">
            </td>
        </tr>
        <tr>
            <td style="text-align:right;padding-top:16px;" colspan="2">
                <a href="/zworks/workflowToDrawIO.jsp" target="_blank">Go to DrawIO XML conversion page</a>
            </td>
        </tr>
    </table>
</form>
</p>
</body>
</html>