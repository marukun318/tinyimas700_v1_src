#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define INFILE_EXT  ".txt"
#define OUTFILE_EXT  ".bin"

#define INBUF_SIZE		65536
#define OUTBUF_SIZE		2000

static unsigned char *inbuf = NULL;
static unsigned char *outbuf = NULL;

static FILE * fp = NULL;

static int opt_c = 0;                                                   /* ���k�t���O */
static unsigned char cmdin[256];
static unsigned char cmdout[256];

// �g�p�@
void usage(void) {
    printf("cge72bin infile[.txt]\n");
}

// ���k�o�͏����i���������O�X�j
void crunch_out(char const * outfile, unsigned char const * databuf) {
	long fpos = 0;
	int len = OUTBUF_SIZE;
	int idx;
	int bit;
	int bcou;
	int runlen;
	unsigned char a;
	unsigned char const * ptr;
	unsigned char const * outptr;
	int outsiz;
	unsigned char outbuf[256];
	FILE * fp;

	fp = fopen(outfile, "wb");
	if (fp == NULL) {
		printf("Can't Create File '%s'.\n", outfile);
		return;
	}

	fputc(0x55, fp);
	fputc(0x55, fp);
	
	// ���������O�X���k
	ptr = databuf;
	bit = 0;
	bcou = 8;
	idx = 0;
	outsiz = 0;
	outptr = outbuf;
	do {
		runlen = 0;
		a = databuf[idx];
		while (a == databuf[idx]) {
			runlen++;
			++idx;
			if (idx >= len || runlen >= 256) {
				break;
			}
		}
//		printf("%02x : runlen=%02x\n", a, runlen);

		bit <<= 1;
		if (runlen >= 3) {
			// ���k�A��
			outbuf[outsiz++] = a;
			outbuf[outsiz++] = (runlen & 0xFF);
			bit |= 1;
//			printf("%02x : %d\n", a, runlen);
		} else {
			// ���k����
			outbuf[outsiz++] = a;
			bit |= 0;
			idx -= (runlen-1);
		}
		
		// �r�b�g�t���b�V���`�F�b�N
		if ((--bcou)==0) {
			fputc(bit, fp);
//			printf("Bit Flash=%02x\n", bit);
			fwrite(outbuf, 1, outsiz, fp);
			bit = 0;
			bcou = 8;
			outsiz = 0;
		}

	} while(idx < len);

	// �t���b�V��
	if (outsiz > 0) {
		bit <<= bcou;
		fputc(bit, fp);
		fwrite(outbuf, 1, outsiz, fp);
	}

	fpos = ftell(fp);
	printf("(%ld/%d) bytes = %d%%\n", fpos, len, (int)((fpos * 100)/len));

	fseek(fp, 0L, SEEK_SET);
	// �t�@�C���擪�ɓW�J��̃t�@�C���T�C�Y����������
//	fpos -= 2;
	fputc(len & 0xFF, fp);
	fputc((len >> 8) & 0xFF, fp);

	fclose(fp);
}

// �ϊ����C������
void cvjob(char const * infile, char const * outfile) {
	char * ptr;
	char * inptr, * outptr;
	int val;
	int st;
	int cou;

	fp = fopen(infile, "rb");
	if (fp == NULL) {
		printf("Can't Open File '%s'.\n", infile);
		return;
	}

	// ���̓o�b�t�@�ɓǂݍ���
	fread(inbuf, 1, INBUF_SIZE, fp);
	fclose(fp);

	// �ϊ�����
	inptr = inbuf;
	outptr = outbuf;
	st = cou = 0;
	do {
		ptr = strchr(inptr, ',');

		if (ptr == NULL) {
			val = atoi(inptr);
		} else {
			*(ptr) = 0;
			val = atoi(inptr);
			inptr = (ptr+1);
		}

		switch (st) {
		  case 0:
			*outptr = (unsigned char) (val & 255);
			if ((val & 0x100)!=0) {
				*(outptr+1000) = 0x80;
			}
			break;
		  case 1:
			*outptr |= (unsigned char) (val << 4);
			break;
		  case 2:
			*outptr |= (unsigned char) val;
			break;
			
		}
		outptr++;
		cou++;

		// �X�e�[�g�ؑփ`�F�b�N
		if (cou == 1000) {
			st++;
		} else
		if (cou == 2000) {
			outptr -= 1000;
			st++;
		} else
		if (cou == 2000) {
			st++;
		}
	} while (ptr != NULL);

	if (opt_c == 0) {
		// �񈳏k
		// �ϊ��o��
		fp = fopen(outfile, "wb");
		if (fp == NULL) {
			printf("Can't Create File '%s'.\n", outfile);
			return;
		}

		// �o�̓o�b�t�@����������
		fwrite(outbuf, OUTBUF_SIZE, 1, fp);
		fclose(fp);
		printf("'%s' Created.\n", outfile);
	} else {
		// ���k�o��
		crunch_out(outfile, outbuf);
	}
}

// ���C���ϊ�����

// Main
int main(int argc, char * argv[]) {
    int a, i;
    char drive[ _MAX_DRIVE ];
    char dir[ _MAX_DIR ];
    char fname[ _MAX_FNAME ];
    char ext[ _MAX_EXT ];
    
    // �t�@�C�����@�N���A
    memset(cmdin, 0, sizeof(cmdin) );
    memset(cmdout, 0, sizeof(cmdout) );

	if (argc <= 1) {
        // �R�}���h���C���w�肪�Ȃ�������A�g�p�@
        usage();
		return 0;
	}

    for (i=1; i<argc; i++) {
        a = argv[i][0];
        if (a == '-' || a == '/') {
            // �I�v�V����
            if (argv[i][1] == 'c') {
//                printf("**** ���k�n�m ****\n");
                opt_c = 1;
            }
            continue;
        }

        // ���̓t�@�C��
        if (cmdin[0] == 0) {
            strncpy(cmdin, argv[i], sizeof(cmdin)-1);
        } else
        if (cmdout[0] == 0) {
            // �o�̓t�@�C��
            strncpy(cmdout, argv[i], sizeof(cmdout)-1);
        }
    }

    // �o�̓t�@�C���w�肪�Ȃ�������A���͂Ɠ����t�@�C�������R�s�[
    if (cmdout[0] == 0) {
        _splitpath(cmdin , drive, dir, fname, ext );
        strncpy(cmdout, fname, sizeof(cmdout)-1);
    }
    //
    _splitpath(cmdin , drive, dir, fname, ext );
    if (ext[0]==0) {
        strcat(cmdin, INFILE_EXT);                                      // ���͊g���q�⊮
    }
    //
    _splitpath(cmdout , drive, dir, fname, ext);
    if (ext[0]==0) {
        strcat(cmdout, OUTFILE_EXT);                                    // �g���q�⊮
    }

	if (cmdin[0] == 0) {
        // ���̓t�@�C���w�肪�Ȃ�������A�g�p�@
        usage();
		return 0;
	}

//    printf("infile='%s'\n", cmdin);
//    printf("outfile='%s'\n", cmdout);

	// �������m��
	inbuf = malloc(INBUF_SIZE);
	outbuf = malloc(OUTBUF_SIZE);
	memset(outbuf, 0, OUTBUF_SIZE);

	// �ϊ�����
	cvjob(cmdin, cmdout);

	// ���������
	free(outbuf);
	free(inbuf);

    return 0;
}
