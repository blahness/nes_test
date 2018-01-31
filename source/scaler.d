module scaler;

import std.algorithm;
import std.math;
import std.stdio;

// Retro scalers for NES native 256 * 240 RGBA image

private enum NATIVE_WIDTH = 256;
private enum NATIVE_HEIGHT = 240;

interface Scaler {
    int factor();
    ubyte* scale(ubyte* src);
}

class NoScaler : Scaler {
    int factor() {
        return 1;
    }

    ubyte* scale(ubyte* src) {
        return src;
    }
}

/*
int max(int a, int b) {
    return a > b ? a : b;
}

int min(int a, int b) {
    return a < b ? a : b;
}
*/

class Scale2x : Scaler {
    this() {
        this.buffer = new ubyte[NATIVE_WIDTH * 2 * NATIVE_HEIGHT * 2 * 4];
    }

    int factor() {
        return 2;
    }

    ubyte* scale(ubyte* src) {
        ubyte* dst = this.buffer.ptr;

        int width = NATIVE_WIDTH;
        int height = NATIVE_HEIGHT;
        int srcPitch = width * 4;
        int dstPitch = width * 2 * 4;

        int looph, loopw;

        uint e0, e1, e2, e3, b, d, e, f, h;

        for (looph = 0; looph < height; ++looph) {
            for(loopw = 0; loopw < width; ++loopw) {
                b = *cast(uint*)(src + (max(0, looph - 1) * srcPitch) + (4 * loopw));
                d = *cast(uint*)(src + (looph * srcPitch) + (4 * max(0, loopw - 1)));
                e = *cast(uint*)(src + (looph * srcPitch) + (4 * loopw));
                f = *cast(uint*)(src + (looph * srcPitch) + (4 * min(width - 1, loopw + 1)));
                h = *cast(uint*)(src + (min(height - 1, looph + 1) * srcPitch) + (4 * loopw));
            
                e0 = d == b && b != f && d != h ? d : e;
                e1 = b == f && b != d && f != h ? f : e;
                e2 = d == h && d != b && h != f ? d : e;
                e3 = h == f && d != h && b != f ? f : e;

                *cast(uint*)(dst + looph * 2 * dstPitch + loopw * 2 * 4) = e0;
                *cast(uint*)(dst + looph * 2 * dstPitch + (loopw * 2 + 1) * 4) = e1;
                *cast(uint*)(dst + (looph * 2 +1)* dstPitch + loopw * 2 * 4) = e2;
                *cast(uint*)(dst + (looph * 2 +1) * dstPitch + (loopw * 2 + 1) * 4) = e3;
            }
        }

        return dst;
    }

    private:
        ubyte[] buffer;
}

class Scale3x : Scaler {
    this() {
        this.buffer = new ubyte[NATIVE_WIDTH * 3 * NATIVE_HEIGHT * 3 * 4];
    }

    int factor() {
        return 3;
    }

    ubyte* scale(ubyte* src) {
        ubyte* dst = this.buffer.ptr;

        int width = NATIVE_WIDTH;
        int height = NATIVE_HEIGHT;
        int srcPitch = width * 4;
        int dstPitch = width * 3 * 4;

        int looph, loopw;

        uint e0, e1, e2, e3, e4, e5, e6, e7, e8;
        uint a, b, c, d, e, f, g, h, i;

        for (looph = 0; looph < height; ++looph) {
            for(loopw = 0; loopw < width; ++loopw) {
                a = *cast(uint*)(src + (max(0, looph - 1) * srcPitch) + (4 * max(0, loopw - 1)));
                b = *cast(uint*)(src + (max(0, looph - 1) * srcPitch) + (4 * loopw));
                c = *cast(uint*)(src + (max(0, looph - 1) * srcPitch) + (4 * min(width - 1, loopw + 1)));
                d = *cast(uint*)(src + (looph * srcPitch) + (4 * max(0, loopw - 1)));
                e = *cast(uint*)(src + (looph * srcPitch) + (4 * loopw));
                f = *cast(uint*)(src + (looph * srcPitch) + (4 * min(width - 1, loopw + 1)));
                g = *cast(uint*)(src + (min(height - 1, looph + 1) * srcPitch) + (4 * max(0, loopw - 1)));
                h = *cast(uint*)(src + (min(height - 1, looph + 1) * srcPitch) + (4 * loopw));
                i = *cast(uint*)(src + (min(height - 1, looph + 1) * srcPitch) + (4 * min(width - 1, loopw + 1)));

                if (b != h && d != f) {
                    e0 = d == b ? d : e;
                    e1 = (d == b && e != c) || (b == f && e != a) ? b : e;
                    e2 = b == f ? f : e;
                    e3 = (d == b && e != g) || (d == h && e != a) ? d : e;
                    e4 = e;
                    e5 = (b == f && e != i) || (h == f && e != c) ? f : e;
                    e6 = d == h ? d : e;
                    e7 = (d == h && e != i) || (h == f && e != g) ? h : e;
                    e8 = h == f ? f : e;
                } else {
                    e0 = e;
                    e1 = e;
                    e2 = e;
                    e3 = e;
                    e4 = e;
                    e5 = e;
                    e6 = e;
                    e7 = e;
                    e8 = e;
                }

                *cast(uint*)(dst + looph * 3 * dstPitch + loopw * 3 * 4) = e0;
                *cast(uint*)(dst + looph * 3 * dstPitch + (loopw * 3 + 1) * 4) = e1;
                *cast(uint*)(dst + looph * 3 * dstPitch + (loopw * 3 + 2) * 4) = e2;
                *cast(uint*)(dst + (looph * 3 + 1) * dstPitch + loopw * 3 * 4) = e3;
                *cast(uint*)(dst + (looph * 3 + 1) * dstPitch + (loopw * 3 + 1) * 4) = e4;
                *cast(uint*)(dst + (looph * 3 + 1) * dstPitch + (loopw * 3 + 2) * 4) = e5;
                *cast(uint*)(dst + (looph * 3 + 2) * dstPitch + loopw * 3 * 4) = e6;
                *cast(uint*)(dst + (looph * 3 + 2) * dstPitch + (loopw * 3 + 1) * 4) = e7;
                *cast(uint*)(dst + (looph * 3 + 2) * dstPitch + (loopw * 3 + 2) * 4) = e8;
            }
        }

        return dst;
    }

    private:
        ubyte[] buffer;
}


class Scale3xFaster : Scaler {
    this() {
        this.buffer = new ubyte[NATIVE_WIDTH * 3 * NATIVE_HEIGHT * 3 * 4];
    }

    int factor() {
        return 3;
    }

    ubyte* scale(ubyte* srcData) {
        uint* src = cast(uint*)srcData;
        uint* dst = cast(uint*)this.buffer.ptr;

        int width = NATIVE_WIDTH;
        int height = NATIVE_HEIGHT;
        int srcPitch = width;
        int dstPitch = width * 3;

        // First row
        scale3x_32_def_whole(dst, dst + dstPitch, dst + (dstPitch * 2),
            src, src, src + srcPitch, width);

        // Middle rows
        foreach(i; 1 .. 239) {
            dst += dstPitch * 3;

            scale3x_32_def_whole(dst, dst + dstPitch, dst + (dstPitch * 2),
                src, src + srcPitch, src + (srcPitch * 2), width);

            src += srcPitch;
        }

        // Last row
        dst += dstPitch * 3;

        scale3x_32_def_whole(dst, dst + dstPitch, dst + (dstPitch * 2),
            src, src + srcPitch, src + srcPitch, width);

        return  cast(ubyte*)this.buffer.ptr;
    }

    private:
        ubyte[] buffer;

        void scale3x_32_def_whole(uint* dst0, uint* dst1, uint* dst2, const(uint)* src0,
                                  const(uint)* src1, const(uint)* src2, uint count)
        {
            assert(count >= 2);

            /* first pixel */
            if (src0[0] != src2[0] && src1[0] != src1[1]) {
                dst0[0] = src1[0];
                dst0[1] = (src1[0] == src0[0] && src1[0] != src0[1]) || (src1[1] == src0[0] && src1[0] != src0[0]) ? src0[0] : src1[0];
                dst0[2] = src1[1] == src0[0] ? src1[1] : src1[0];
                dst1[0] = (src1[0] == src0[0] && src1[0] != src2[0]) || (src1[0] == src2[0] && src1[0] != src0[0]) ? src1[0] : src1[0];
                dst1[1] = src1[0];
                dst1[2] = (src1[1] == src0[0] && src1[0] != src2[1]) || (src1[1] == src2[0] && src1[0] != src0[1]) ? src1[1] : src1[0];
                dst2[0] = src1[0];
                dst2[1] = (src1[0] == src2[0] && src1[0] != src2[1]) || (src1[1] == src2[0] && src1[0] != src2[0]) ? src2[0] : src1[0];
                dst2[2] = src1[1] == src2[0] ? src1[1] : src1[0];
            } else {
                dst0[0] = src1[0];
                dst0[1] = src1[0];
                dst0[2] = src1[0];
                dst1[0] = src1[0];
                dst1[1] = src1[0];
                dst1[2] = src1[0];
                dst2[0] = src1[0];
                dst2[1] = src1[0];
                dst2[2] = src1[0];
            }
            ++src0;
            ++src1;
            ++src2;
            dst0 += 3;
            dst1 += 3;
            dst2 += 3;

            /* central pixels */
            count -= 2;
            while (count) {
                if (src0[0] != src2[0] && src1[-1] != src1[1]) {
                    dst0[0] = src1[-1] == src0[0] ? src1[-1] : src1[0];
                    dst0[1] = (src1[-1] == src0[0] && src1[0] != src0[1]) || (src1[1] == src0[0] && src1[0] != src0[-1]) ? src0[0] : src1[0];
                    dst0[2] = src1[1] == src0[0] ? src1[1] : src1[0];
                    dst1[0] = (src1[-1] == src0[0] && src1[0] != src2[-1]) || (src1[-1] == src2[0] && src1[0] != src0[-1]) ? src1[-1] : src1[0];
                    dst1[1] = src1[0];
                    dst1[2] = (src1[1] == src0[0] && src1[0] != src2[1]) || (src1[1] == src2[0] && src1[0] != src0[1]) ? src1[1] : src1[0];
                    dst2[0] = src1[-1] == src2[0] ? src1[-1] : src1[0];
                    dst2[1] = (src1[-1] == src2[0] && src1[0] != src2[1]) || (src1[1] == src2[0] && src1[0] != src2[-1]) ? src2[0] : src1[0];
                    dst2[2] = src1[1] == src2[0] ? src1[1] : src1[0];
                } else {
                    dst0[0] = src1[0];
                    dst0[1] = src1[0];
                    dst0[2] = src1[0];
                    dst1[0] = src1[0];
                    dst1[1] = src1[0];
                    dst1[2] = src1[0];
                    dst2[0] = src1[0];
                    dst2[1] = src1[0];
                    dst2[2] = src1[0];
                }

                ++src0;
                ++src1;
                ++src2;
                dst0 += 3;
                dst1 += 3;
                dst2 += 3;
                --count;
            }

            /* last pixel */
            if (src0[0] != src2[0] && src1[-1] != src1[0]) {
                dst0[0] = src1[-1] == src0[0] ? src1[-1] : src1[0];
                dst0[1] = (src1[-1] == src0[0] && src1[0] != src0[0]) || (src1[0] == src0[0] && src1[0] != src0[-1]) ? src0[0] : src1[0];
                dst0[2] = src1[0];
                dst1[0] = (src1[-1] == src0[0] && src1[0] != src2[-1]) || (src1[-1] == src2[0] && src1[0] != src0[-1]) ? src1[-1] : src1[0];
                dst1[1] = src1[0];
                dst1[2] = (src1[0] == src0[0] && src1[0] != src2[0]) || (src1[0] == src2[0] && src1[0] != src0[0]) ? src1[0] : src1[0];
                dst2[0] = src1[-1] == src2[0] ? src1[-1] : src1[0];
                dst2[1] = (src1[-1] == src2[0] && src1[0] != src2[0]) || (src1[0] == src2[0] && src1[0] != src2[-1]) ? src2[0] : src1[0];
                dst2[2] = src1[0];
            } else {
                dst0[0] = src1[0];
                dst0[1] = src1[0];
                dst0[2] = src1[0];
                dst1[0] = src1[0];
                dst1[1] = src1[0];
                dst1[2] = src1[0];
                dst2[0] = src1[0];
                dst2[1] = src1[0];
                dst2[2] = src1[0];
            }
        }
}
