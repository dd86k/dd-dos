/*
 * Loader.d : File loader.
 */

module Loader;

import std.stdio, std.path, std.file;
import dd_dos, Interpreter, InterpreterUtils, Logger;

/// MS-DOS EXE header
private struct mz_hdr {
	ushort e_magic;        /* Magic number, "MZ" */
	ushort e_cblp;         /* Bytes on last page of file */
	ushort e_cp;           /* Pages in file */
	ushort e_crlc;         /* Relocations */
	ushort e_cparh;        /* Size of header in paragraphs */
	ushort e_minalloc;     /* Minimum extra paragraphs needed */
	ushort e_maxalloc;     /* Maximum extra paragraphs needed */
	ushort e_ss;           /* Initial (relative) SS value */
	ushort e_sp;           /* Initial SP value */
	ushort e_csum;         /* Checksum */
	ushort e_ip;           /* Initial IP value */
	ushort e_cs;           /* Initial (relative) CS value */
	ushort e_lfarlc;       /* File address of relocation table */
	ushort e_ovno;         /* Overlay number */
	ushort[ERESWDS] e_res; /* Reserved words */
	uint   e_lfanew;       /* File address of new exe header */
}
private enum ERESWDS = 16;

private struct mz_rlc { // For AL=03h
    ushort segment, relocation; // reloc factor
}

/// MZ file magic
private enum MZ_MAGIC = 0x5A4D;

/**
 * Load a file in memory.
 * Params:
 *   path = Path to executable
 *   args = Executable arguments
 */
void LoadFile(string path, string args = null)
{
    if (exists(path))
    {
        import core.stdc.string : memcpy;
        import std.uni : toUpper;
        File f = File(path);

        const ulong fsize = f.size;

        if (Verbose) log("File exists");

        if (fsize == 0)
        {
            if (Verbose) log("File is zero length.", LogLevel.Error);
            return;
        }

        if (fsize <= 0xFFF_FFFFL)
        {
            switch (toUpper(extension(f.name)))
            {
                case ".COM": {
                    if (fsize > 0xFF00) // Size - PSP
                    {
                        if (Verbose) log("COM file too large", LogLevel.Error);
                        AL = 3;
                        return;
                    }
                    if (Verbose) log("Loading COM... ");
                    uint s = cast(uint)fsize;
                    ubyte[] buf = new ubyte[s];
                    f.rawRead(buf);
                    CS = 0; IP = 0x100;
                    ubyte* bankp = &bank[0] + IP;
                    memcpy(bankp, &buf[0], buf.length);

                    //MakePSP(GetIPAddress - 0x100, "TEST");
                }
                    break;

                case ".EXE": { // Real party starts here
                    if (Verbose) log("Loading EXE... ");
                    mz_hdr mzh;
                    {
                        ubyte[mz_hdr.sizeof] buf;
                        f.rawRead(buf);
                        memcpy(&mzh, &buf, mz_hdr.sizeof);
                    }

                    if (mzh.e_magic != MZ_MAGIC) {
                        if (Verbose) log("EXEC failed magic test");
                        AL = 3;
                        return;
                    }

                    with (mzh) {
                        /*if (e_lfanew)
                        {
                            char[2] sig;
                            f.seek(e_lfanew);
                            f.rawRead(sig);
                            switch (sig)
                            {
                            //case "NE":
                            default:
                            }
                        }*/

                        if (Verbose) log("Type: MZ");

                        if (e_minalloc && e_maxalloc) // High memory
                        {
                            if (Verbose) log("HIGH MEM");
                        }
                        else // Low memory
                        {
                            if (Verbose) log("LOW MEM");
                        }

                        const uint headersize = e_cparh * 16;
                        uint imagesize = (e_cp * 512) - headersize;
                        if (e_cblp) imagesize -= 512 - e_cblp;
                        /*if (headersize + imagesize < 512)
                        imagesize = 512 - headersize;*/

                        logd("HDR_SIZE: ", headersize);
                        logd("IMG_SIZE: ", imagesize);

                        if (e_crlc)
                        {
                            if (Verbose) log("Relocating...");
                            f.seek(e_lfarlc);
                            // Relocation table
                            mz_rlc[] rlct = new mz_rlc[e_crlc];
                            f.rawRead(rlct);

                            const int m = e_crlc * 2;
                            for (int i = 0; i < m; i += 2)
                            { //TODO: relocations

                            }
                        }
                        else if (Verbose) log("No relocations");

                        /*uint minsize = imagesize + (e_minalloc << 4) + 256;
                        uint maxsize = e_maxalloc ?
                            imagesize + (e_maxalloc << 4) + 256 :
                            0xFFFF;*/

                        DS = ES = 0; // DS:ES (??????)
                        
                        CS = e_cs;
                        IP = e_ip;
                        //CS = 0;
                        //IP = 0x100;
                        SS = e_ss;
                        SP = e_sp;
                        //uint l = GetIPAddress;

                        ubyte[] t = new ubyte[imagesize];
                        f.seek(headersize);
                        f.rawRead(t);
                        Insert(t);

                        // Make PSP
                        //MakePSP(GetIPAddress, "test");
                    }
                }
                    break; // case ".EXE"

                default: break; // null is included here.
            }
        }
        else if (Verbose) writeln("[VMLE] File is too big.");
    }
    else if (Verbose)
        writefln("[VMLE] File %s does not exist, skipping.", path);
}