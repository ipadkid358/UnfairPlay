#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>

#import "SharedStrings.h"

// Thanks https://bitbucket.org/lordscotland/dump/src/master/decrypt.c

static size_t stream_copy(FILE *src, FILE *dest, size_t maxlen) {
    size_t nbytes = 0;
    while (!feof(src)) {
        char buf[8192];
        bool end = (maxlen && nbytes + sizeof(buf) >= maxlen);
        nbytes += fwrite(buf, 1, fread(buf, 1, end ? maxlen - nbytes : sizeof(buf), src), dest);
        if (end) {
            break;
        }
    }
    
    return nbytes;
}

static __attribute__((constructor)) void _loadDump() {
    @autoreleasepool {
        NSDictionary *readDict = [NSDictionary dictionaryWithContentsOfFile:@kDictPath];
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        NSString *topDecrytDir = readDict[bundleID];
        if (!topDecrytDir) {
            return;
        }
        
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"yyyy-MM-dd-HH-mm-ss";
        
        NSString *dateID = [dateFormatter stringFromDate:NSDate.date];
        NSString *basePath = [NSString stringWithFormat:@"%@/%@-%@", topDecrytDir, bundleID, dateID];
        
        NSError *createErr = NULL;
        [NSFileManager.defaultManager createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:NULL error:&createErr];
        if (createErr) {
            notify_post(kPostFailKey);
            return;
        }
        
        NSDictionary *writeDict = @{ bundleID : basePath };
        [writeDict writeToFile:[topDecrytDir stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
        
        Dl_info info;
        void *self = dladdr(&_loadDump, &info) ? info.dli_fbase : NULL;
        int i, imax = _dyld_image_count();
        for (i = 0; i < imax; i++) {
            const struct mach_header *mh = _dyld_get_image_header(i);
            if (mh == self) {
                continue;
            }
            
            size_t hsize = (mh->magic == MH_MAGIC_64) ? sizeof(struct mach_header_64) : sizeof(struct mach_header);
            struct load_command *lc = (void *)((char *)mh + hsize);
            struct encryption_info_command *eic = NULL;
            int ncmds = mh->ncmds;
            while (ncmds--) {
                if (lc->cmd == LC_ENCRYPTION_INFO || lc->cmd == LC_ENCRYPTION_INFO_64) {
                    eic = (void *)lc;
                    break;
                }
                lc = (void *)((char *)lc + lc->cmdsize);
            }
            
            const char *fname = _dyld_get_image_name(i);
            
            FILE *fh = fopen(fname, "rb");
            if (fh) {
                if (eic && eic->cryptid) {
                    uint32_t slice_offset, slice_size;
                    struct fat_header fat;
                    fread(&fat, sizeof(struct fat_header), 1, fh);
                    bool swap = (fat.magic == FAT_CIGAM);
                    if (swap || fat.magic == FAT_MAGIC) {
                        uint32_t narch = fat.nfat_arch;
                        cpu_type_t mtype = mh->cputype;
                        cpu_subtype_t msubtype = mh->cpusubtype;
                        if (swap) {
                            narch = __builtin_bswap32(narch);
                            mtype = __builtin_bswap32(mtype);
                            msubtype = __builtin_bswap32(msubtype);
                        }
                        while (narch--) {
                            struct fat_arch arch;
                            fread(&arch, sizeof(struct fat_arch), 1, fh);
                            if (arch.cputype == mtype && arch.cpusubtype == msubtype) {
                                slice_offset = swap ? __builtin_bswap32(arch.offset) : arch.offset;
                                slice_size = swap ? __builtin_bswap32(arch.size) : arch.size;
                                goto __writeFile;
                            }
                        }
                    } else if (fat.magic == mh->magic) {
                        slice_offset = slice_size = 0;
                        __writeFile : {
                            char *outname = strrchr(fname, '/');
                            NSString *outFileName = [NSString stringWithFormat:@"%@/%s.%d", basePath, (outname ? outname + 1 : fname), i];
                            FILE *outfh = fopen(outFileName.UTF8String, "wb");
                            if (outfh) {
                                struct encryption_info_command eic0 = { .cmd = eic->cmd, .cmdsize = eic->cmdsize };
                                size_t pos = fwrite(mh, 1, (char *)eic - (char *)mh, outfh);
                                pos += fwrite(&eic0, 1, sizeof(eic0), outfh);
                                pos += fwrite((char *)mh + pos, 1, hsize + mh->sizeofcmds - pos, outfh);
                                fseek(fh, slice_offset + pos, SEEK_SET);
                                if (eic->cryptoff > pos) {
                                    pos += stream_copy(fh, outfh, eic->cryptoff - pos);
                                }
                                pos += fwrite((char *)mh + pos, 1, eic->cryptsize, outfh);
                                fseek(fh, eic->cryptsize, SEEK_CUR);
                                pos += stream_copy(fh, outfh, slice_size ? slice_size - pos : 0);
                                fclose(outfh);
                            } else {
                                perror("fopen");
                            }
                        }
                    }
                }
                
                fclose(fh);
            }
        }
        
        notify_post(kPostDoneKey);
        exit(0);
    }
}
