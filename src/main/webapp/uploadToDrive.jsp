<%--

Upload a file to Google Drive. In order to enable this code, you must set up a Google account (free) and
configure a Google Drive application. All details and instructions for creating a Google Drive application can be found
at: https://developers.google.com/drive/.

The ToDo items below must be completed before this code will be functional.

TODO Item 1:
Once you have created your Drive application, you must replace the CLIENT_ID, CLIENT_SECRET, and REDIRECT_URI values below
to match the values in your application. See https://developers.google.com/drive/ for more details.

TODO Item 2:
You must also set the path for the saving of temporary files. These temporary files will hold that data that is to be
uploaded to Google Drive.

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

--%><%@ page import="com.google.api.client.googleapis.auth.oauth2.GoogleAuthorizationCodeFlow,
                 com.google.api.client.http.HttpTransport,
                 com.google.api.client.json.JsonFactory,
                 com.google.api.client.json.jackson2.JacksonFactory,
                 com.google.api.services.drive.DriveScopes,
                 com.google.api.services.drive.DriveScopes" %>
<%@ page import="com.google.api.client.http.javanet.NetHttpTransport" %>
<%@ page import="java.util.Arrays" %>
<%@ page import="org.apache.log4j.Logger" %>
<%@ page import="com.google.api.client.googleapis.auth.oauth2.GoogleTokenResponse" %>
<%@ page import="com.google.api.client.googleapis.auth.oauth2.GoogleCredential" %>
<%@ page import="com.google.api.services.drive.Drive" %>
<%@ page import="com.google.api.services.drive.model.File" %>
<%@ page import="com.google.api.client.http.FileContent" %>
<%@ page import="java.io.*" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%!
    private static final Logger logger = Logger.getLogger("com.zpaper.zworks.uploadToDrive");
    // TODO Item 1
    // Set values to match your Google Drive application.
    private static String CLIENT_ID = "YOUR CLIENT ID HERE";
    private static String CLIENT_SECRET = "YOUR CLIENT SECRET HERE";
    private static String REDIRECT_URI = "YOUR REDIRECT URI HERE";

    private String getTempFile(String fileName, String fileContents) {
        // TODO Item 2
        // Set file path where temp files will be created.
        java.io.File outFile = new java.io.File("SET THE DIRECTORY PATH HERE", fileName);
        BufferedOutputStream bout = null;
        BufferedInputStream bin = null;
        try {
            bout = new BufferedOutputStream(new FileOutputStream(outFile));
            byte[] buffer = new byte[2048];
            int bytesRead;
            bin = new BufferedInputStream(new ByteArrayInputStream(fileContents.getBytes("utf-8")));
            do {
                bytesRead = bin.read(buffer);
                if (bytesRead > 0) {
                    bout.write(buffer, 0, bytesRead);
                }
            }
            while (bytesRead >= 0);
            bout.flush();
            return outFile.getAbsolutePath();
        }
        catch (IOException e) {
            logger.error("Error writing to temp file (" + outFile.getAbsolutePath() + "): " + e, e);
        }
        finally {
            if (null != bin) { try { bin.close(); } catch (Exception e) { /* don't care */ } }
            if (null != bout) { try { bout.close(); } catch (Exception e) { /* don't care */ } }
        }
        return null;
    }

    private static void oauthRedirect(HttpServletResponse response) {
        try {
            HttpTransport httpTransport = new NetHttpTransport();
            JsonFactory jsonFactory = new JacksonFactory();

            GoogleAuthorizationCodeFlow flow = new GoogleAuthorizationCodeFlow.Builder(
                    httpTransport, jsonFactory, CLIENT_ID, CLIENT_SECRET, Arrays.asList(DriveScopes.DRIVE))
                    .setAccessType("online")
                    .setApprovalPrompt("auto").build();

            String url = flow.newAuthorizationUrl().setRedirectUri(REDIRECT_URI).build();
            logger.debug("@@@ Google Drive url = " + url);

            response.sendRedirect(url);
        }
        catch (IOException e) {
            logger.error("Exception redirecting to Google oauth: " + e.getLocalizedMessage(), e);
        }
    }
%>
<%
    // This jsp can be called in two different ways: 1) the initial call and 2) in response to the oauth redirect. If
    // the oauth authentication is successful, we will save the xml into the file the user specified.
    String status = "Saving file to Google Drive failed.";      // assume failure
    String drawIOXml = request.getParameter("drawioXML");
    logger.debug("drawIOXml parameter: " + (null != drawIOXml ? (drawIOXml.length() > 80 ? drawIOXml.substring(0, 80) : drawIOXml) : "NONE"));
    String driveFileName = request.getParameter("fileName");
    logger.debug("driveFileName parameter: " + driveFileName);
    String googleCode = request.getParameter("code");
    logger.debug("googleCode parameter: " + googleCode);
    GoogleCredential credential = (GoogleCredential)request.getSession().getAttribute("GoogleCredential");
    logger.debug("credential pulled from session: " + credential);
    HttpTransport httpTransport = new NetHttpTransport();
    JsonFactory jsonFactory = new JacksonFactory();
    if (null != driveFileName && !driveFileName.endsWith(".xml")) {
        logger.debug("@@@ adding .xml extension to filename: " + driveFileName);
        driveFileName += ".xml";
    }
    if (null == credential && null == googleCode) {
        logger.debug("Redirecting to Google for OAuth authentication.");
        if (null != drawIOXml && null != driveFileName) {
            logger.debug("Saving drive name: " + driveFileName + " into our session.");
            logger.debug("Saving drawIOXml into our session: " + (drawIOXml.length() > 80 ? drawIOXml
                    .substring(0, 80) : drawIOXml));
            // save for when the oauth authentication returns
            request.getSession().setAttribute("drawIOXml", drawIOXml);
            request.getSession().setAttribute("driveFileName", driveFileName);
        }
        // This is the initial call; redirect to Google for oauth authentication.
        oauthRedirect(response);
        logger.debug("$$$$ returning here $$$$");
        return;
    }
    if (null == credential) {
        logger.debug("@@@@ googleCode = " + googleCode);
        request.getSession().setAttribute("GoogleCode", googleCode);
        GoogleAuthorizationCodeFlow flow = new GoogleAuthorizationCodeFlow.Builder(
                httpTransport, jsonFactory, CLIENT_ID, CLIENT_SECRET, Arrays.asList(DriveScopes.DRIVE))
                .setAccessType("online")
                .setApprovalPrompt("auto").build();
        GoogleTokenResponse tokenResponse = flow.newTokenRequest(googleCode).setRedirectUri(REDIRECT_URI).execute();
        logger.debug("Google Id Token = " + tokenResponse.getIdToken());
        logger.debug("Google Access Token = " + tokenResponse.getAccessToken());
        logger.debug("Google Refresh Token = " + tokenResponse.getRefreshToken());
        logger.debug("Google Token Type = " + tokenResponse.getTokenType());
        logger.debug("Google Expires in seconds = " + tokenResponse.getExpiresInSeconds());
        logger.debug("Google Scope = " + tokenResponse.getScope());
        credential = new GoogleCredential().setFromTokenResponse(tokenResponse);
        request.getSession().setAttribute("GoogleCredential", credential);
    }
    if (null != credential) {   // make sure the authentication worked
        logger.debug("@@@ Google Credential pulled from session or created: " + credential);
        // We authenticated successfully; this is a file upload.
        if (null == drawIOXml) {
            drawIOXml = (String)request.getSession().getAttribute("drawIOXml");
            driveFileName = (String)request.getSession().getAttribute("driveFileName");
        }
        logger.debug("@@@ After OAuth Authentication: driveFileName = " + driveFileName);
        logger.debug("@@@ After OAuth Authentication: drawIOXml = " +
                    (null != drawIOXml ? (drawIOXml.length() > 80 ? drawIOXml.substring(0, 80) : drawIOXml) : "NONE"));
        //Create a new authorized API client
        Drive service = new Drive.Builder(httpTransport, jsonFactory, credential).build();
        File body = new File();
        body.setTitle(driveFileName);
        body.setDescription("File uploaded by zPaper");
        body.setMimeType("application/xml");
        String uploadedFile = getTempFile(driveFileName, drawIOXml);
        logger.debug("@@@@ uploading file: " + uploadedFile);
        if (null != uploadedFile) {
            java.io.File fileContent = new java.io.File(uploadedFile);
            FileContent mediaContent = new FileContent("application/xml", fileContent);
            // Now do the uplaod
            File googleFile = service.files().insert(body, mediaContent).execute();
            status = driveFileName + " was successfully saved to Google Drive";
        }
    }

%>
<html>
<head>
    <title>Google Drive Sandbox Application</title>
</head>
<body>
<h1><%=status%></h1>

<br/>
<a href="/zworks/workflowToDrawIO.jsp">Back to DrawIO XML conversion page</a>
<br/>
<a href="https://drive.google.com/" target="_blank">Go to Google Drive</a>
</body>
</html>
