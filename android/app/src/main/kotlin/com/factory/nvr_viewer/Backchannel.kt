package com.factory.nvr_viewer

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.math.BigInteger
import java.net.Socket
import java.security.MessageDigest
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.random.Random

/**
 * Two-way audio sender over an ONVIF Profile-T RTSP backchannel.
 *
 * Pipeline: AudioRecord(VOICE_COMMUNICATION, with AEC+NS) -> PCM16 8kHz mono
 * -> G.711 u-law -> RTP (PT 0) -> RTSP interleaved TCP channel to the NVR.
 *
 * The NVR must advertise a backchannel track (a=sendonly) in its DESCRIBE SDP
 * when the request carries `Require: www.onvif.org/ver20/backchannel`. If it
 * does not, start() reports UNSUPPORTED.
 *
 * NOTE: requires verification against the real NVR (firmware backchannel
 * support varies). Audio capture/encode/RTP are standard; the RTSP digest +
 * SDP parse is the part to confirm on-device.
 */
class Backchannel(
    messenger: io.flutter.plugin.common.BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val method = MethodChannel(messenger, "nvr/backchannel").apply {
        setMethodCallHandler(this@Backchannel)
    }
    private val event = EventChannel(messenger, "nvr/backchannel/level").apply {
        setStreamHandler(this@Backchannel)
    }

    private var levelSink: EventChannel.EventSink? = null
    private var session: TalkSession? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startTalk(call, result)
            "stop" -> {
                session?.stop(); session = null; result.success(null)
            }
            "setMuted" -> {
                session?.muted = call.argument<Boolean>("muted") ?: false
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startTalk(call: MethodCall, result: MethodChannel.Result) {
        if (session != null) { result.success(null); return }
        val host = call.argument<String>("host")!!
        val user = call.argument<String>("user") ?: ""
        val pass = call.argument<String>("pass") ?: ""
        val aec = call.argument<Boolean>("aec") ?: true
        val ns = call.argument<Boolean>("ns") ?: true
        thread {
            try {
                val s = TalkSession(host, user, pass, aec, ns) { lvl ->
                    levelSink?.let { sink ->
                        android.os.Handler(android.os.Looper.getMainLooper())
                            .post { sink.success(lvl) }
                    }
                }
                s.open() // throws UnsupportedOperationException if no backchannel
                session = s
                s.run()
                android.os.Handler(android.os.Looper.getMainLooper())
                    .post { result.success(null) }
            } catch (e: UnsupportedOperationException) {
                android.os.Handler(android.os.Looper.getMainLooper())
                    .post { result.error("UNSUPPORTED", e.message, null) }
            } catch (e: Exception) {
                android.os.Handler(android.os.Looper.getMainLooper())
                    .post { result.error("TALK_FAILED", e.message, null) }
            }
        }
    }

    override fun onListen(args: Any?, sink: EventChannel.EventSink?) { levelSink = sink }
    override fun onCancel(args: Any?) { levelSink = null }
}

/** One RTSP backchannel + mic-send session. */
private class TalkSession(
    private val host: String,
    private val user: String,
    private val pass: String,
    private val aec: Boolean,
    private val ns: Boolean,
    private val onLevel: (Double) -> Unit,
) {
    var muted = false
    @Volatile private var running = false

    private lateinit var socket: Socket
    private lateinit var reader: BufferedReader
    private var cseq = 1
    private var interleavedChannel = 0
    private var nonce: String? = null
    private var realm: String? = null
    private val rtpPort get() = 554
    private val rtspUrl =
        "rtsp://$host:554/cam/realmonitor?channel=1&subtype=0"

    /** RTSP OPTIONS/DESCRIBE/SETUP/PLAY negotiating the backchannel track. */
    fun open() {
        socket = Socket(host, 554)
        socket.tcpNoDelay = true
        reader = BufferedReader(InputStreamReader(socket.getInputStream()))

        request("OPTIONS", rtspUrl, null)
        val (descCode, descBody, descHeaders) = request(
            "DESCRIBE", rtspUrl,
            "Accept: application/sdp\r\n" +
                "Require: www.onvif.org/ver20/backchannel\r\n"
        )
        if (descCode == 401) {
            parseAuth(descHeaders)
            val retry = request(
                "DESCRIBE", rtspUrl,
                "Accept: application/sdp\r\n" +
                    "Require: www.onvif.org/ver20/backchannel\r\n"
            )
            if (retry.first != 200) throw UnsupportedOperationException(
                "DESCRIBE failed (${retry.first})"
            )
            negotiate(retry.second)
        } else if (descCode == 200) {
            negotiate(descBody)
        } else {
            throw UnsupportedOperationException("DESCRIBE returned $descCode")
        }
    }

    private fun negotiate(sdp: String) {
        // Find the sendonly (client->server) audio backchannel control URL.
        val control = parseBackchannelControl(sdp)
            ?: throw UnsupportedOperationException("No backchannel track in SDP")
        interleavedChannel = 0
        val setupUrl = if (control.startsWith("rtsp://")) control else "$rtspUrl/$control"
        val (code, _, _) = request(
            "SETUP", setupUrl,
            "Transport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n"
        )
        if (code != 200) throw IllegalStateException("SETUP failed ($code)")
        val play = request("PLAY", rtspUrl, null)
        if (play.first != 200) throw IllegalStateException("PLAY failed (${play.first})")
    }

    /** Capture mic -> AEC/NS -> u-law -> RTP interleaved frames. */
    fun run() {
        running = true
        val sampleRate = 8000
        val frameSamples = 160 // 20 ms
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(frameSamples * 2 * 4)

        val recorder = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION, // OS AEC/NS path
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBuf
        )
        val echo = if (aec && AcousticEchoCanceler.isAvailable())
            AcousticEchoCanceler.create(recorder.audioSessionId)?.apply { enabled = true } else null
        val noise = if (ns && NoiseSuppressor.isAvailable())
            NoiseSuppressor.create(recorder.audioSessionId)?.apply { enabled = true } else null

        val pcm = ShortArray(frameSamples)
        val out = socket.getOutputStream()
        var seq = Random.nextInt(0, 0xFFFF)
        var timestamp = Random.nextInt()
        val ssrc = Random.nextInt()

        recorder.startRecording()
        try {
            while (running) {
                val n = recorder.read(pcm, 0, frameSamples)
                if (n <= 0) continue
                var peak = 0
                val payload = ByteArray(n)
                for (i in 0 until n) {
                    val s = if (muted) 0 else pcm[i].toInt()
                    if (abs(s) > peak) peak = abs(s)
                    payload[i] = linearToUlaw(s)
                }
                onLevel((peak / 32768.0).coerceIn(0.0, 1.0))

                val rtp = buildRtp(payload, seq, timestamp, ssrc)
                // RTSP interleaved framing: '$' + channel + 2-byte length
                val frame = ByteArray(4 + rtp.size)
                frame[0] = '$'.code.toByte()
                frame[1] = interleavedChannel.toByte()
                frame[2] = ((rtp.size shr 8) and 0xFF).toByte()
                frame[3] = (rtp.size and 0xFF).toByte()
                System.arraycopy(rtp, 0, frame, 4, rtp.size)
                out.write(frame); out.flush()

                seq = (seq + 1) and 0xFFFF
                timestamp += n
            }
        } finally {
            recorder.stop(); recorder.release()
            echo?.release(); noise?.release()
        }
    }

    fun stop() {
        running = false
        try { request("TEARDOWN", rtspUrl, null) } catch (_: Exception) {}
        try { socket.close() } catch (_: Exception) {}
    }

    // --- RTSP plumbing ---

    private fun request(
        method: String, url: String, extraHeaders: String?
    ): Triple<Int, String, Map<String, String>> {
        val sb = StringBuilder()
        sb.append("$method $url RTSP/1.0\r\n")
        sb.append("CSeq: ${cseq++}\r\n")
        sb.append("User-Agent: nvr_viewer\r\n")
        nonce?.let { sb.append(authHeader(method, url)) }
        extraHeaders?.let { sb.append(it) }
        sb.append("\r\n")
        socket.getOutputStream().write(sb.toString().toByteArray())
        socket.getOutputStream().flush()
        return readResponse()
    }

    private fun readResponse(): Triple<Int, String, Map<String, String>> {
        val status = reader.readLine() ?: return Triple(0, "", emptyMap())
        val code = Regex("RTSP/1\\.0 (\\d+)").find(status)?.groupValues?.get(1)?.toInt() ?: 0
        val headers = mutableMapOf<String, String>()
        var contentLength = 0
        while (true) {
            val line = reader.readLine() ?: break
            if (line.isEmpty()) break
            val idx = line.indexOf(':')
            if (idx > 0) {
                val k = line.substring(0, idx).trim()
                val v = line.substring(idx + 1).trim()
                headers[k] = v
                if (k.equals("Content-Length", true)) contentLength = v.toIntOrNull() ?: 0
                if (k.equals("WWW-Authenticate", true)) headers["WWW-Authenticate"] = v
            }
        }
        val body = if (contentLength > 0) {
            val buf = CharArray(contentLength); reader.read(buf, 0, contentLength); String(buf)
        } else ""
        return Triple(code, body, headers)
    }

    private fun parseAuth(headers: Map<String, String>) {
        val h = headers["WWW-Authenticate"] ?: return
        realm = Regex("realm=\"([^\"]+)\"").find(h)?.groupValues?.get(1)
        nonce = Regex("nonce=\"([^\"]+)\"").find(h)?.groupValues?.get(1)
    }

    private fun authHeader(method: String, url: String): String {
        val r = realm ?: return ""; val n = nonce ?: return ""
        val ha1 = md5("$user:$r:$pass")
        val ha2 = md5("$method:$url")
        val response = md5("$ha1:$n:$ha2")
        return "Authorization: Digest username=\"$user\", realm=\"$r\", " +
            "nonce=\"$n\", uri=\"$url\", response=\"$response\"\r\n"
    }

    private fun md5(s: String): String {
        val d = MessageDigest.getInstance("MD5").digest(s.toByteArray())
        return BigInteger(1, d).toString(16).padStart(32, '0')
    }

    private fun parseBackchannelControl(sdp: String): String? {
        // Walk media sections; pick the audio one marked sendonly (client->server).
        var inAudio = false
        var sendonly = false
        var control: String? = null
        for (raw in sdp.lines()) {
            val line = raw.trim()
            if (line.startsWith("m=")) {
                if (inAudio && sendonly && control != null) return control
                inAudio = line.startsWith("m=audio")
                sendonly = false; control = null
            } else if (inAudio && line == "a=sendonly") {
                sendonly = true
            } else if (inAudio && line.startsWith("a=control:")) {
                control = line.removePrefix("a=control:")
            }
        }
        return if (inAudio && sendonly) control else null
    }

    private fun buildRtp(payload: ByteArray, seq: Int, ts: Int, ssrc: Int): ByteArray {
        val pkt = ByteArray(12 + payload.size)
        pkt[0] = 0x80.toByte()          // version 2
        pkt[1] = 0x00                   // PT 0 = PCMU
        pkt[2] = ((seq shr 8) and 0xFF).toByte()
        pkt[3] = (seq and 0xFF).toByte()
        pkt[4] = ((ts shr 24) and 0xFF).toByte()
        pkt[5] = ((ts shr 16) and 0xFF).toByte()
        pkt[6] = ((ts shr 8) and 0xFF).toByte()
        pkt[7] = (ts and 0xFF).toByte()
        pkt[8] = ((ssrc shr 24) and 0xFF).toByte()
        pkt[9] = ((ssrc shr 16) and 0xFF).toByte()
        pkt[10] = ((ssrc shr 8) and 0xFF).toByte()
        pkt[11] = (ssrc and 0xFF).toByte()
        System.arraycopy(payload, 0, pkt, 12, payload.size)
        return pkt
    }

    /** ITU-T G.711 mu-law encode of one 16-bit PCM sample. */
    private fun linearToUlaw(sample: Int): Byte {
        val bias = 0x84; val clip = 32635
        var s = sample
        val sign = if (s < 0) { s = -s; 0x80 } else 0
        if (s > clip) s = clip
        s += bias
        var exponent = 7
        var mask = 0x4000
        while (exponent > 0 && (s and mask) == 0) { exponent--; mask = mask shr 1 }
        val mantissa = (s shr (exponent + 3)) and 0x0F
        return (((sign or (exponent shl 4) or mantissa).inv()) and 0xFF).toByte()
    }
}
