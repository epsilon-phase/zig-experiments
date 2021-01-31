// Compile with -lc -lpulse-simple -lfftw3
const std = @import("std");
const pulseaudio = @cImport({
    @cInclude("pulse/simple.h");
    @cInclude("pulse/error.h");
});
const fftw = @cImport({
    @cInclude("fftw3.h");
});
const SAMPLE_COUNT = 4096 * 2;
var samplesIn: [SAMPLE_COUNT]fftw.fftw_complex = undefined;
var samplesIntermediate: [SAMPLE_COUNT]fftw.fftw_complex = undefined;
var samplesOut: [SAMPLE_COUNT]fftw.fftw_complex = undefined;
var plan_in: fftw.fftw_plan = undefined;
var plan_out: fftw.fftw_plan = undefined;
var pulse_conn_in: ?*pulseaudio.pa_simple = undefined;
var pulse_conn_out: ?*pulseaudio.pa_simple = undefined;
fn initialize_pulse() void {
    const options: pulseaudio.pa_sample_spec = .{
        .format = @intToEnum(pulseaudio.enum_pa_sample_format, pulseaudio.PA_SAMPLE_FLOAT32LE),
        .rate = 44100,
        .channels = 1,
    };
    pulse_conn_in = pulseaudio.pa_simple_new(null, "FFTW", @intToEnum(pulseaudio.enum_pa_stream_direction, pulseaudio.PA_STREAM_RECORD), null, "hhe", &options, null, null, null);
    pulse_conn_out = pulseaudio.pa_simple_new(null, "FFTW", @intToEnum(pulseaudio.enum_pa_stream_direction, pulseaudio.PA_STREAM_PLAYBACK), null, "hhe", &options, null, null, null);
}
fn initialize_fftw() void {
    plan_in = fftw.fftw_plan_dft_1d(SAMPLE_COUNT, &samplesIn, &samplesIntermediate, fftw.FFTW_FORWARD, fftw.FFTW_MEASURE);
    plan_out = fftw.fftw_plan_dft_1d(SAMPLE_COUNT, &samplesIntermediate, &samplesOut, fftw.FFTW_BACKWARD, fftw.FFTW_MEASURE);
}
fn fftw_step_1() void {
    fftw.fftw_execute(plan_in);
}
fn fftw_step_2() void {
    fftw.fftw_execute(plan_out);
}
fn destroy_fft() void {
    fftw.fftw_destroy_plan(plan_in);
    fftw.fftw_destroy_plan(plan_out);
}
fn read_pulse_buffer() void {
    var samples: [SAMPLE_COUNT]f32 = undefined;

    var err: c_int = undefined;
    var ret = pulseaudio.pa_simple_read(pulse_conn_in, &samples, @sizeOf(f32) * SAMPLE_COUNT, &err);
    if (ret != 0) {
        std.debug.print("Issue! {}\n", .{pulseaudio.pa_strerror(err)});
    }
    var i: usize = 0;
    var avg: f32 = 0.0;
    while (i < samplesIn.len) {
        samplesIn[i] = .{ samples[i], 0.0 };
        avg += samples[i];
        i += 1;
    }
    avg /= SAMPLE_COUNT;
    std.debug.print("Average amplitude {}\n", .{avg});
}
fn write_pulse_buffer() void {
    var samples: [SAMPLE_COUNT]f32 = undefined;

    var i: usize = 0;
    while (i < samplesOut.len) {
        samples[i] = @floatCast(f32, samplesOut[i][0] / SAMPLE_COUNT);
        i += 1;
    }
    _ = pulseaudio.pa_simple_write(pulse_conn_out, &samples, @sizeOf(f32) * SAMPLE_COUNT, null);
}

fn initialize_sample_arrays() void {
    for (samplesIn) |*s| {
        s.* = .{ 0.0, 0.0 };
    }
    for (samplesOut) |*s| {
        s.* = .{ 0.0, 0.0 };
    }
}
fn interfere() void {
    var i: usize = 0;
    while (i < SAMPLE_COUNT / 2) {
        // samplesOut[i + SAMPLE_COUNT / 2] = samplesOut[i];
        samplesIntermediate[i + SAMPLE_COUNT / 2][0] += samplesIntermediate[i][0];
        samplesIntermediate[i + SAMPLE_COUNT / 2][1] += samplesIntermediate[i][1];
        // samplesOut[i + SAMPLE_COUNT / 2] = .{ 0.0, 0.0 };
        // samplesIntermediate[i] = .{ 0.0, 0.0 };
        i += 1;
    }
    i = 0;
    while (i < 3) {
        samplesIntermediate[SAMPLE_COUNT / 2 + i] = .{ SAMPLE_COUNT, 1 };
        samplesIntermediate[SAMPLE_COUNT / 2 - i] = .{ SAMPLE_COUNT, 1 };
        i += 1;
    }
    // for (samplesIntermediate[SAMPLE_COUNT / 2 .. SAMPLE_COUNT]) |*s| {
    //     s.* = .{ 0.0, 0.0 };
    // }
}
fn difference() void {
    var i: usize = 0;
    var sum: f64 = 0.0;
    while (i < SAMPLE_COUNT) {
        sum += std.math.absFloat(samplesIn[i][0] - samplesOut[i][0] / SAMPLE_COUNT);
        i += 1;
    }
    std.debug.print("Average diff: {} \n", .{sum / SAMPLE_COUNT});
}
pub fn main() void {
    defer pulseaudio.pa_simple_free(pulse_conn_in);
    defer pulseaudio.pa_simple_free(pulse_conn_out);
    initialize_pulse();
    if (pulse_conn_in != null and pulse_conn_out != null) {
        std.debug.print("Yay!", .{});
    }
    initialize_sample_arrays();
    initialize_fftw();
    while (true) {
        // initialize_sample_arrays();
        read_pulse_buffer();
        fftw_step_1();
        interfere();
        fftw_step_2();
        difference();
        // var sample: usize = 0;
        // while (sample < SAMPLE_COUNT) {
        //     samplesOut[sample] = samplesIn[sample];
        //     sample += 1;
        // }
        write_pulse_buffer();
    }
}
