<?php
// USER/PHP/payment.php
ob_start();

// 1. SET TIMEZONE
date_default_timezone_set('Asia/Manila');

// 2. SECURITY HEADERS (UPDATED for Tesseract.js)
header("X-Frame-Options: DENY");
header("X-Content-Type-Options: nosniff");

// 🟢 FIX: Added 'unsafe-eval', 'blob:', 'worker-src', and 'connect-src' to allow Tesseract
header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net blob:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com; font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com; img-src 'self' data: blob:; connect-src 'self' https://cdn.jsdelivr.net https://tessdata.projectnaptha.com blob: data:; worker-src 'self' blob:;");

// 3. SECURE SESSION
if (session_status() === PHP_SESSION_NONE) {
    $cookieParams = session_get_cookie_params();
    session_set_cookie_params([
        'lifetime' => $cookieParams['lifetime'],
        'path' => $cookieParams['path'],
        'domain' => $cookieParams['domain'],
        'secure' => true, // Ensure TRUE for production (False for Localhost XAMPP)
        'httponly' => true,
        'samesite' => 'Lax'
    ]);
    session_start();
}

require 'db_connect.php';

// 4. ACCESS CONTROL
if (!isset($_SESSION['temp_booking'])) {
    header("Location: guest_info.php");
    exit;
}

$bookingData = $_SESSION['temp_booking'];
$method = $bookingData['payment_method']; 
$totalPrice = floatval($bookingData['total_price']);
$paymentTerm = $bookingData['payment_term'];

// Calculate Amount Due
$amountDue = ($paymentTerm === 'partial') ? ($totalPrice / 2) : $totalPrice;

// 5. FETCH QR CODE (SECURE QUERY)
$sql = "SELECT * FROM payment_settings WHERE method_name = ? LIMIT 1";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $method);
$stmt->execute();
$result = $stmt->get_result();
$paymentSetting = $result->fetch_assoc();

$qrImage = $paymentSetting['qr_image_path'] ?? ''; 
$accName = $paymentSetting['account_name'] ?? 'Admin';
$accNum = $paymentSetting['account_number'] ?? '';

// 6. CSRF TOKEN GENERATION (If not set)
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Complete Payment - AMV Hotel</title>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">

    <script src='https://cdn.jsdelivr.net/npm/tesseract.js@4/dist/tesseract.min.js'></script>

    <link rel="stylesheet" href="../STYLE/home_page.css">
    <style>
        /* Custom Scrollbar */
        ::-webkit-scrollbar {
            width: 8px;
            background-color: transparent;
        }
        ::-webkit-scrollbar-track {
            background-color: transparent !important;
        }
        ::-webkit-scrollbar-thumb {
            background: #b8860b;
            border-radius: 10px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: #9e8236;
        }
        /* Firefox */
        * {
            scrollbar-width: thin;
            scrollbar-color: #b8860b transparent;
        }

        body {
            background-color: #f9f9f9;
            font-family: 'Montserrat', sans-serif;
            margin: 0;
            padding: 0;
        }

        /* --- PAYMENT PAGE CONTENT --- */
        .main-content {
            padding-top: 50px;
            padding-bottom: 50px;
        }

        .payment-container {
            max-width: 550px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.08);
            text-align: center;
            border-top: 5px solid #9e8236;
        }

        .payment-container h2 {
            font-size: 1.8rem;
            font-weight: 800;
            color: #222;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .qr-box {
            background: #fdfdfd;
            padding: 30px;
            border: 2px dashed #e0e0e0;
            margin: 25px 0;
            border-radius: 12px;
            transition: all 0.3s ease;
        }

        .qr-box:hover {
            border-color: #9e8236;
            background: #fffdf5;
        }

        #receiptPreviewContainer:hover {
            border-color: #b8860b !important;
            background-color: #fffdf5 !important;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(158, 130, 54, 0.1);
        }

        .qr-img {
            width: 100%;
            max-width: 220px;
            height: auto;
            border-radius: 8px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }

        .amount-display {
            font-size: 1.8rem;
            color: #9e8236;
            font-weight: 800;
            margin: 15px 0;
            padding: 15px;
            background: #fffdf5;
            border-radius: 8px;
            border: 1px solid #f9f5e8;
        }

        .details-text {
            color: #666;
            font-size: 0.95rem;
            margin-bottom: 8px;
        }

        .details-text b { color: #333; }

        .file-input-wrapper {
            margin-top: 25px;
            text-align: left;
        }

        .file-input {
            width: 100%;
            padding: 12px;
            border: 2px solid #eee;
            border-radius: 8px;
            background: #fcfcfc;
            font-family: inherit;
            cursor: pointer;
            transition: 0.3s;
        }

        .file-input:focus {
            border-color: #9e8236;
            outline: none;
        }

        .btn-confirm {
            width: 100%;
            padding: 18px;
            background-color: #222;
            color: white;
            border: none;
            border-radius: 8px;
            font-weight: 800;
            cursor: pointer;
            margin-top: 25px;
            text-transform: uppercase;
            letter-spacing: 2px;
            transition: all 0.3s ease;
            font-size: 0.95rem;
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 10px;
        }

        .btn-confirm:hover:not(:disabled) {
            background-color: #9e8236;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(158, 130, 54, 0.3);
        }

        .btn-confirm:disabled {
            background-color: #eee;
            color: #aaa;
            cursor: not-allowed;
        }

        .back-link {
            display: inline-block;
            margin-top: 20px;
            color: #888;
            text-decoration: none;
            font-size: 0.9rem;
            font-weight: 600;
            transition: 0.3s;
        }

        .back-link:hover { color: #333; }

        /* --- LOADER CSS --- */
        #booking-processing {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: #9e8236;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            z-index: 100000;
            opacity: 0;
            visibility: hidden;
            transition: all 0.4s ease;
            color: #ffffff !important;
        }

        #booking-processing.active {
            opacity: 1;
            visibility: visible;
        }

        .booking-spinner {
            width: 70px;
            height: 70px;
            border: 5px solid rgba(255, 255, 255, 0.2);
            border-radius: 50%;
            border-top-color: #ffffff;
            animation: spin 1s linear infinite;
            margin-bottom: 25px;
        }

        @keyframes spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }

        .booking-text {
            text-align: center;
            color: #ffffff !important;
        }

        .booking-text h2 {
            font-size: 2rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 2px;
            margin: 0 0 10px 0;
            color: #ffffff !important;
        }

        .booking-text p {
            font-size: 1.1rem;
            opacity: 0.9;
            margin: 0;
            color: #ffffff !important;
        }

        @media (max-width: 600px) {
            .payment-container {
                margin: 0 15px;
                padding: 30px 20px;
            }
            .payment-container h2 { font-size: 1.5rem; }
            .amount-display { font-size: 1.5rem; }
        }
    </style>
</head>

    
<body>
    <div class="main-content" style="padding-top: 50px;">
        <div class="payment-container">
            <h2><i class="fa-solid fa-qrcode"></i> Scan to Pay</h2>
            <p style="color: #666; font-size: 0.95rem; margin-bottom: 25px;">Please scan the QR code below using <b><?php echo htmlspecialchars($method); ?></b>.</p>

            <div class="qr-box">
                <?php if (!empty($qrImage)): ?>
                    <img src="../../room_includes/uploads/payment/<?php echo htmlspecialchars(basename($qrImage)); ?>"
                        class="qr-img" alt="Payment QR Code">
                <?php else: ?>
                    <p style="padding: 20px; color: #d32f2f; font-weight: 600;">No QR Code Available. Please contact support.</p>
                <?php endif; ?>

                <div style="margin-top: 20px; text-align: left; padding: 0 10px;">
                    <p class="details-text">Account Name: <b><?php echo htmlspecialchars($accName); ?></b></p>
                    <p class="details-text">Account Number: <b><?php echo htmlspecialchars($accNum); ?></b></p>
                </div>
            </div>

            <div class="amount-display">
                <span style="font-size: 0.8rem; display: block; color: #888; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 5px;">Amount Due</span>
                ₱<?php echo number_format($amountDue, 2); ?>
            </div>

            <form action='finalize_booking.php' method='POST' enctype='multipart/form-data' id='paymentForm' onsubmit='handlePaymentSubmit(event)'>
                <input type='hidden' name='csrf_token' value='<?php echo $_SESSION["csrf_token"]; ?>'>
                <input type='hidden' name='payment_reference' id='extractedRefInput'>
                <input type='hidden' name='actual_amount' id='actualAmountInput'>

                <input type="hidden" name="checkin" value="<?php echo htmlspecialchars($bookingData['checkin']); ?>">
                <input type="hidden" name="checkout" value="<?php echo htmlspecialchars($bookingData['checkout']); ?>">
                <input type="hidden" name="adults" value="<?php echo $bookingData['adults']; ?>">
                <input type="hidden" name="children" value="<?php echo $bookingData['children']; ?>">
                <input type="hidden" name="total_price" value="<?php echo $totalPrice; ?>">
                <input type="hidden" name="selected_rooms" value="<?php echo htmlspecialchars(json_encode($bookingData['selected_rooms']), ENT_QUOTES, 'UTF-8'); ?>">

                <div class="file-input-wrapper">
                    <label style='font-weight: 700; font-size: 0.95rem; color: #222; display: block; margin-bottom: 15px;'>
                        <i class='fas fa-camera-retro'></i> Click Box to Upload Receipt
                    </label>

                    <!-- 🟢 IMAGE PREVIEW BOX (Now acting as trigger) -->
                    <div id='receiptPreviewContainer' onclick="document.getElementById('receiptInput').click()" style='width: 100%; min-height: 220px; background: #fdfdfd; border: 2px dashed #9e8236; border-radius: 12px; display: flex; align-items: center; justify-content: center; overflow: hidden; position: relative; margin-bottom: 15px; transition: 0.3s; cursor: pointer;'>
                        <div id='previewPlaceholder' style='text-align: center; color: #aaa; padding: 20px;'>
                            <i class='fas fa-cloud-upload-alt' style='font-size: 3.5rem; display: block; margin-bottom: 15px; color: #eee;'></i>
                            <span style='font-size: 0.85rem; font-weight: 500;'>Tap or Click here to upload GCash receipt</span>
                        </div>
                        <img id='receiptPreviewImage' src='#' alt='Receipt Preview' style='display: none; width: 100%; height: auto; max-height: 350px; object-fit: contain; z-index: 2;'>
                        
                        <!-- Floating Edit Icon (Visible after upload) -->
                        <div id="editOverlay" style="position:absolute; top:10px; right:10px; background:rgba(0,0,0,0.5); color:white; width:30px; height:30px; border-radius:50%; display:none; align-items:center; justify-content:center; z-index:10;">
                            <i class="fas fa-pen" style="font-size:0.8rem;"></i>
                        </div>
                    </div>

                    <!-- Hidden File Input -->
                    <input type='file' name='receipt_image' id='receiptInput' accept='image/*' required onchange='analyzeReceipt(event)' style='display: none;'>
                    
                    <small style='color: #999; display: block; margin-top: 8px; font-weight: 500; text-align: center;'>High resolution JPG or PNG recommended</small>

                    <!-- 🟢 VALIDATION CHECKLIST BOX -->
                    <div id='analysisMsg' style='display:none; border-radius: 12px; padding: 20px; margin-top: 20px; border: 1px solid #f0f0f0; background: #fafafa; transition: all 0.3s ease;'>
                        <div style='font-weight: 800; margin-bottom: 15px; font-size: 0.9rem; color: #333; text-transform: uppercase; letter-spacing: 1px;'>
                            <i class='fas fa-shield-halved'></i> Verification Status
                        </div>
                        <div id='checklistContent'>
                            <!-- JS will inject items here -->
                        </div>
                    </div>
                </div>

                <button type='submit' class='btn-confirm' id='payBtn' disabled>
                    Complete Booking <i class="fa-solid fa-circle-check"></i>
                </button>
            </form>

            <a href="guest_info.php" class="back-link"><i class="fa-solid fa-arrow-left-long"></i> Cancel & Go Back</a>
        </div>
    </div>

    <div id="booking-processing">
        <div class="booking-spinner"></div>
        <div class="booking-text">
            <h2 id="loaderTitle">Verifying Payment</h2>
            <p id="loaderDesc">Please wait while we secure your booking...</p>
        </div>
    </div>

    <script>
        const REQUIRED_AMOUNT = <?php echo $amountDue; ?>;
        const FORMATTED_AMOUNT = "<?php echo number_format($amountDue, 2); ?>";
        const RECIPIENT_NUMBER = "<?php echo $accNum; ?>"; // 🟢 Hotel's Official Number
        
        let scheduler = null;
        let isScannerReady = false;

        // 🟢 1. PRE-INITIALIZE SCANNER ON PAGE LOAD
        async function initScanner() {
            const checklistContainer = document.getElementById('checklistContent');
            const msg = document.getElementById('analysisMsg');
            
            try {
                // Show initialization status
                msg.style.display = "block";
                msg.style.backgroundColor = "#fefce8";
                msg.style.borderColor = "#fef08a";
                msg.style.color = "#854d0e";
                msg.innerHTML = '<div style="font-weight:bold; margin-bottom:5px;"><i class="fas fa-robot"></i> Preparing Scanner...</div><div id="initStatus" style="font-size:0.75rem;">Downloading AI models (one-time setup)...</div>';

                const worker = await Tesseract.createWorker({
                    logger: m => {
                        const statusDiv = document.getElementById('initStatus');
                        if (statusDiv && m.status === 'loading tesseract core') statusDiv.innerText = "Loading engine...";
                        if (statusDiv && m.status === 'loading language traineddata') statusDiv.innerText = "Loading language models...";
                        if (statusDiv && m.status === 'initializing api') statusDiv.innerText = "Finalizing setup...";
                    }
                });

                await worker.loadLanguage('eng');
                await worker.initialize('eng');
                
                scheduler = worker;
                isScannerReady = true;
                
                // Hide or update to "Ready"
                msg.style.display = "none";
                console.log("Tesseract Scanner Ready");
            } catch (err) {
                console.error("Scanner Init Error:", err);
                const statusDiv = document.getElementById('initStatus');
                if (statusDiv) statusDiv.innerText = "Scanner offline. Manual verification required.";
            }
        }

        document.addEventListener('DOMContentLoaded', initScanner);

        async function analyzeReceipt(event) {
            const input = event.target;
            const msg = document.getElementById('analysisMsg'); 
            const btn = document.getElementById('payBtn');      
            const refInput = document.getElementById('extractedRefInput');
            const checklist = document.getElementById('checklistContent');

            previewReceipt(event);

            if (!input.files || !input.files[0]) return;        

            const file = input.files[0];

            btn.disabled = true;
            btn.style.opacity = "0.6";
            btn.innerText = "SCANNING RECEIPT...";
            if(refInput) refInput.value = ""; 

            msg.style.display = "block";
            msg.style.backgroundColor = "#f0f9ff";
            msg.style.color = "#0369a1";
            msg.style.borderColor = "#bae6fd";
            msg.innerHTML = '<div style="font-weight:800; margin-bottom:15px; font-size:0.9rem; color:#333; text-transform:uppercase; letter-spacing:1px;"><i class="fas fa-shield-halved"></i> Verification Status</div><div id="checklistContent" style="text-align:center; padding: 10px;"><i class="fas fa-spinner fa-spin" style="font-size:1.5rem; margin-bottom:10px; display:block;"></i> Reading Receipt Text...</div>';

            try {
                // 🟢 2. USE PRE-LOADED SCHEDULER (MUCH FASTER)
                let text = "";
                if (isScannerReady && scheduler) {
                    const result = await scheduler.recognize(file);
                    text = result.data.text;
                } else {
                    // Fallback if not ready yet
                    const result = await Tesseract.recognize(file, 'eng');
                    text = result.data.text;
                }

                const lowerText = text.toLowerCase();
                const cleanText = text.replace(/,/g, '');

                console.log("OCR OUTPUT:\n", text);

                const providerKeywords = ['gcash', 'express', 'send', 'sent', 'total', 'amount', 'receipt', 'successful', 'confirmed', 'payment', 'peso', 'php', 'maya', 'transfer'];
                const hasProvider = providerKeywords.some(w => lowerText.includes(w));

                // 🟢 ENHANCED REFERENCE EXTRACTION (Handles split lines & labels)
                const findReference = (rawText) => {
                    // 1. Clean the text: remove common labels that might split the number
                    const cleaned = rawText.replace(/(ref|no|reference|number|:|\s)+/gi, '');
                    const bigMatch = cleaned.match(/\d{13}/);
                    if (bigMatch) return bigMatch[0];

                    // 2. Fallback: Join all numeric clusters and look for 13 digits
                    // (This handles cases where the OCR adds random symbols between lines)
                    const allDigits = rawText.replace(/\D/g, '');
                    const digitsMatch = allDigits.match(/\d{13}/);
                    if (digitsMatch) return digitsMatch[0];

                    // 3. Last Resort: Proximity stitching
                    const clusters = rawText.match(/\d{3,}/g) || [];
                    for (let i = 0; i < clusters.length; i++) {
                        if (clusters[i+1]) {
                            const combined = clusters[i] + clusters[i+1];
                            if (combined.length === 13) return combined;
                        }
                    }
                    return null;
                };

                const foundRef = findReference(text);
                const hasRef = foundRef !== null;

                const datePattern = /(\d{4}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i; 
                const timePattern = /(\d{1,2}:\d{2})/;
                const hasDateTime = datePattern.test(lowerText) && timePattern.test(lowerText); 

                // 🟢 Smart Amount Validation: Strictly accept only the EXACT amount
                const targetVal = parseFloat(REQUIRED_AMOUNT);
                const targetFmt = targetVal.toFixed(2);
                
                const allNumbers = cleanText.match(/\b\d+(\.\d{1,2})?\b/g) || [];
                
                let hasCorrectAmount = false;
                let foundAmount = 0;
                let bestMatch = null;

                for (const numStr of allNumbers) {
                    if (numStr.length > 10) continue; 
                    
                    const val = parseFloat(numStr);
                    
                    // 🔴 STRICT CHECK: Must be the EXACT amount
                    if (val === targetVal) {
                        bestMatch = val;
                        hasCorrectAmount = true;
                        break; // Found exact match
                    }
                }

                if (bestMatch !== null) {
                    foundAmount = bestMatch;
                }

                let isUnique = true;
                if (hasRef) {
                    try {
                        const checkRes = await fetch(`../../API/api_check_reference.php?ref=${foundRef}`);
                        const checkData = await checkRes.json();
                        if (checkData.success && checkData.is_duplicate) isUnique = false;
                    } catch (e) { console.error("Uniqueness check failed", e); }
                }

                // 🟢 Recipient Number Validation
                const last4Digits = RECIPIENT_NUMBER.slice(-4);
                const hasRecipientMatch = cleanText.includes(RECIPIENT_NUMBER) || cleanText.includes(last4Digits);

                let statusHtml = checkItem("GCash / Payment Receipt", hasProvider);
                statusHtml += checkItem("13-digit Ref Number", hasRef);
                if (hasRef && !isUnique) statusHtml += '<div class="check-item check-fail"><i class="fas fa-times-circle"></i> Reference Already Used</div>';
                statusHtml += checkItem("Transaction Timestamp", hasDateTime);
                statusHtml += checkItem(`Exact Amount (₱${targetFmt})`, hasCorrectAmount);
                statusHtml += checkItem("Recipient Match", hasRecipientMatch);

                const checklistContainer = document.getElementById('checklistContent');
                const amountInput = document.getElementById('actualAmountInput');
                if (checklistContainer) {
                    if (hasProvider && hasRef && isUnique && hasDateTime && hasCorrectAmount && hasRecipientMatch) {
                        msg.style.backgroundColor = "#f0fdf4";      
                        msg.style.color = "#15803d";
                        msg.style.borderColor = "#bbf7d0";
                        const finalMsg = `<div style="margin-top:15px; padding-top:10px; border-top:1px solid #bbf7d0; font-weight:800; text-transform:uppercase; font-size:0.8rem;"><i class="fas fa-check-circle"></i> RECEIPT VERIFIED</div>`;
                        checklistContainer.innerHTML = statusHtml + finalMsg;
                        if(refInput) refInput.value = foundRef;
                        if(amountInput) amountInput.value = foundAmount;
                        btn.disabled = false;
                        btn.style.opacity = "1";
                        btn.innerText = "COMPLETE BOOKING";
                    } else {
                        msg.style.backgroundColor = "#fef2f2";      
                        msg.style.color = "#b91c1c";
                        msg.style.borderColor = "#fecaca";
                        let hint = "Please upload a clearer copy."; 
                        if (!hasCorrectAmount) hint = `Receipt amount must be exactly <b>₱${targetFmt}</b>.`;
                        if (!hasRecipientMatch) hint = `This receipt was not sent to the hotel's account (ending in ${last4Digits}).`;
                        if (hasRef && !isUnique) hint = `This receipt has already been used.`;
                        if (!hasRef) hint = `Could not find valid Reference Number.`;
                        const failMsg = `<div style="margin-top:15px; padding-top:10px; border-top:1px solid #fecaca; font-weight:800; text-transform:uppercase; font-size:0.8rem;"><i class="fas fa-triangle-exclamation"></i> VERIFICATION FAILED</div><div style="font-size:0.8rem; margin-top:5px; opacity:0.8;">${hint}</div>`;
                        checklistContainer.innerHTML = statusHtml + failMsg;
                        btn.disabled = true;
                        btn.innerText = "INVALID RECEIPT";
                    }
                }
            } catch (error) {
                console.error(error);
                if(msg) {
                    msg.style.backgroundColor = "#fef2f2";
                    msg.innerHTML = "Error scanning image. Please use a clearer photo.";
                }
                btn.disabled = true;
                btn.innerText = "ANALYSIS ERROR";
            }
        }

        function checkItem(label, passed) {
            const icon = passed ? '<i class="fas fa-check-circle"></i>' : '<i class="fas fa-times-circle"></i>';
            const colorClass = passed ? 'check-pass' : 'check-fail';
            return `<div class="check-item ${colorClass}">${icon} ${label}</div>`;
        }

        function previewReceipt(event) {
            const input = event.target;
            const previewImage = document.getElementById('receiptPreviewImage');
            const placeholder = document.getElementById('previewPlaceholder');
            const container = document.getElementById('receiptPreviewContainer');
            const editOverlay = document.getElementById('editOverlay');

            if (input.files && input.files[0]) {
                const reader = new FileReader();
                reader.onload = function (e) {
                    previewImage.src = e.target.result;
                    previewImage.style.display = 'block';
                    placeholder.style.display = 'none';
                    container.style.borderStyle = 'solid';
                    if (editOverlay) editOverlay.style.display = 'flex';
                }
                reader.readAsDataURL(input.files[0]);
            } else {
                previewImage.src = '#';
                previewImage.style.display = 'none';
                placeholder.style.display = 'block';
                container.style.borderStyle = 'dashed';
                if (editOverlay) editOverlay.style.display = 'none';
            }
        }

        function handlePaymentSubmit(event) {
            event.preventDefault();
            const form = document.getElementById('paymentForm');
            if (!form.checkValidity()) { form.reportValidity(); return; }

            const loader = document.getElementById('booking-processing');
            const title = document.getElementById('loaderTitle');
            const desc = document.getElementById('loaderDesc');
            loader.classList.add('active');

            setTimeout(() => {
                title.innerText = "Finalizing Booking";
                desc.innerText = "Almost there...";
            }, 1000);

            setTimeout(() => { form.submit(); }, 2000);
        }

        window.addEventListener("pageshow", function (event) {
            document.getElementById('booking-processing').classList.remove('active');
        });
    </script>

</body>

</html>