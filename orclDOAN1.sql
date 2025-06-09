-- IV. CREATE TRIGGER
-- Kiem tra vi pham vung bien
CREATE OR REPLACE TRIGGER TRG_check_VI_PHAM
AFTER INSERT ON LOG_HAI_TRINH
FOR EACH ROW
DECLARE
    v_poly SDO_GEOMETRY;
    v_Count NUMBER;
    v_contains  NUMBER := 0;  -- khởi tạo mặc định
BEGIN
    -- Lấy vùng ngư trường
    SELECT nt.ViTri
    INTO v_poly
    FROM CHUYEN_DANH_BAT cdb
    JOIN NGU_TRUONG nt ON nt.MaNguTruong = cdb.MaNguTruong
    WHERE cdb.MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    -- Đếm số vi phạm hiện tại
    SELECT count(*)
    INTO v_Count
    FROM VI_PHAM vp
    WHERE vp.MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    -- Kiểm tra SDO_CONTAINS an toàn
    BEGIN
        IF v_poly IS NOT NULL AND :NEW.ViTri IS NOT NULL THEN
            SELECT SDO_CONTAINS(v_poly, :NEW.ViTri)
            INTO v_contains
            FROM DUAL;
            -- Nếu NULL thì gán 0
            IF v_contains IS NULL THEN
                v_contains := 0;
            END IF;
        ELSE
            v_contains := 0;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20065,
                'Error in TRG_check_VI_PHAM: SDO_CONTAINS, ' || SQLERRM);
    END;

    IF v_contains = 0 AND v_Count = 0 THEN
        insert_VI_PHAM(:NEW.MaChuyenDanhBat, :NEW.ThoiGian, SDO_UTIL.TO_WKTGEOMETRY(:NEW.ViTri), 'Vi pham vung bien');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Error in TRG_check_VI_PHAM: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT SAN LUONG CHUYEN DANH BAT
CREATE OR REPLACE TRIGGER TRG_update_weight
AFTER INSERT ON DANHBAT_THUYSAN
FOR EACH ROW
BEGIN
    UPDATE ME_CA
    SET KhoiLuongMeCa = KhoiLuongMeCa + :NEW.KhoiLuong
    WHERE MaMeCa = :NEW.MaMeCa AND MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

    UPDATE CHUYEN_DANH_BAT
    SET TongKhoiLuong = TongKhoiLuong + :NEW.KhoiLuong
    WHERE MaChuyenDanhBat = :NEW.MaChuyenDanhBat;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20002,
            'Error in TRG_update_weight: ' || SQLERRM);
END;
/

--check ThoiGianThaLuoi va ThoiGianKeoLuoi
CREATE OR REPLACE TRIGGER TRG_check_date_ME_CA
BEFORE INSERT OR UPDATE ON ME_CA
FOR EACH ROW
DECLARE
    v_NgayXuatBen date;
    v_MaChuyenDanhBat ME_CA.MaChuyenDanhBat%TYPE;
BEGIN
    v_MaChuyenDanhBat := :NEW.MaChuyenDanhBat;
    
    SELECT NgayXuatBen
    INTO v_NgayXuatBen
    FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = v_MaChuyenDanhBat;

    IF :NEW.ThoiGianThaLuoi < v_NgayXuatBen OR :NEW.ThoiGianThaLuoi > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20032, 'Error in TRG_check_date_ME_CA: ThoiGianThaLuoi khong dung');
    ELSIF :NEW.ThoiGianKeoLuoi < :NEW.ThoiGianThaLuoi OR :NEW.ThoiGianKeoLuoi > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20033, 'Error in TRG_check_date_ME_CA: ThoiGianKeoLuoi khong dung');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20002,
            'Error in TRG_check_date_ME_CA: ' || SQLERRM);
END;
/
--checked

-- V. CREATE PROCEDURE

-- PROCEDURE LAY DU LIEU
-- Lay danh sach tat ca TAU_CA
CREATE OR REPLACE PROCEDURE get_ships_list(
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, SoDangKy
        FROM TAU_CA;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20003,
            'Error in get_ships_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach TAU_CA cua CHU_TAU
CREATE OR REPLACE PROCEDURE get_owner_ships_list(
    p_cursor OUT SYS_REFCURSOR,
    p_MaChuTau   CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, SoDangKy
        FROM TAU_CA t 
        WHERE t.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20004,
            'Error in get_owner_ships_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach CHU_TAU cho duyet
CREATE OR REPLACE PROCEDURE get_owners_pending_list(
    chu_tau_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN chu_tau_cursor FOR
        SELECT MaChuTau, HoTen, CCCD, TrangThaiDuyet
        FROM CHU_TAU ct
        WHERE ct.TrangThaiDuyet = 'DANG CHO';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20005,
            'Error in get_owners_pending_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach TAU_CA cho duyet
CREATE OR REPLACE PROCEDURE get_ships_pending_list(
    p_cursor OUT SYS_REFCURSOR
)
IS 
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, SoDangKy, TrangThaiDuyet
        FROM TAU_CA tc
        WHERE tc.TrangThaiDuyet = 'DANG CHO';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20006,
            'Error in get_ships_pending_list: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin chi tiet CHU_TAU
CREATE OR REPLACE PROCEDURE get_owner_info(
    chu_tau_cursor OUT SYS_REFCURSOR,
    p_MaChuTau      CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN chu_tau_cursor FOR
        SELECT *
        FROM CHU_TAU ct
        WHERE ct.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20007,
            'Error in get_owner_info: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin chi tiet TAU_CA
CREATE OR REPLACE PROCEDURE get_ship_info(
    tau_ca_cursor OUT SYS_REFCURSOR,
    p_MaTauCa      TAU_CA.MaTauCa%TYPE
)
IS
BEGIN
    OPEN tau_ca_cursor FOR
        SELECT * 
        FROM TAU_CA tc
        WHERE tc.MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20008,
            'Error in get_ship_info: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach TAU_CA va trang thai hoat dong TAU_CA cua CHU_TAU
CREATE OR REPLACE PROCEDURE get_owner_ships_list_and_working_status(
    tau_ca_cursor OUT SYS_REFCURSOR,
    p_MaChuTau        TAU_CA.MaChuTau%TYPE
)
IS
BEGIN
    OPEN tau_ca_cursor FOR
        SELECT tc.MaTauCa, tc.SoDangKy, tc.TrangThaiHoatDong 
        FROM TAU_CA tc 
        WHERE tc.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20009,
            'Error in get_owner_ships_list_and_working_status: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin CHUYEN_DANH_BAT
CREATE OR REPLACE PROCEDURE get_voyages_info(
    cdb_cursor OUT SYS_REFCURSOR,
    p_MaChuyenDanhBat   CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE
)
IS
BEGIN
    OPEN cdb_cursor FOR
        SELECT *
        FROM CHUYEN_DANH_BAT cdb
        WHERE cdb.MaChuyenDanhBat = p_MaChuyenDanhBat;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20010,
            'Error in get_voyages_info: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach CHUYEN_DANH_BAT cho duyet
CREATE OR REPLACE PROCEDURE get_voyages_pending_list(
    cdb_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN cdb_cursor FOR
        SELECT cdb.MaTauCa, cdb.MaChuyenDanhBat, cdb.TrangThaiDuyet
        FROM CHUYEN_DANH_BAT cdb
        WHERE cdb.TrangThaiDuyet = 'DANG CHO';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20011,
            'Error in get_voyages_pending_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach CHUYEN_DANH_BAT cua TAU_CA
CREATE OR REPLACE PROCEDURE get_ship_voyages_list(
    cdb_cursor OUT SYS_REFCURSOR,
    p_MaTauCa   CHUYEN_DANH_BAT.MaTauCa%TYPE
)
IS
BEGIN
    OPEN cdb_cursor FOR
        SELECT cdb.MaChuyenDanhBat, cdb.TrangThaiHoatDong 
        FROM CHUYEN_DANH_BAT cdb
        WHERE cdb.MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20012,
            'Error in get_ship_voyages_list: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach tat ca TAU_CA DANG HOAT DONG
CREATE OR REPLACE PROCEDURE get_working_ships_list(
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT * FROM TAU_CA t WHERE t.TRANGTHAIHOATDONG ='DANG HOAT DONG';

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20013,
            'Error in get_working_ships_list: ' || SQLERRM);
END;
/
--xem lai

-- Lay danh sach cac NGU_TRUONG
CREATE OR REPLACE PROCEDURE get_fishery_list(
    ngu_truong_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN ngu_truong_cursor FOR
        SELECT ng.MaNguTruong, ng.TenNguTruong 
        FROM NGU_TRUONG ng;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20014,
            'Error in get_fishery_list: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin THOI_TIET moi nhat
CREATE OR REPLACE PROCEDURE get_weather_info(
    weather_cursor OUT SYS_REFCURSOR,
    NgayDuBao   DATE
)
IS
    p_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO p_count
    FROM THOI_TIET
    WHERE TRUNC(ThoiGianDuBao) = TRUNC(NgayDuBao);

    IF p_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20034, 'Error in get_weather_info: Khong co du bao cho ngay ' || TO_CHAR(NgayDuBao, 'YYYY-MM-DD'));
    END IF;

    OPEN weather_cursor FOR
        SELECT *
        FROM THOI_TIET
        WHERE TRUNC(ThoiGianDuBao) = TRUNC(NgayDuBao)
        ORDER BY ThoiGianDuBao ASC;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20015,
            'Error in get_weather_info: ' || SQLERRM);
END;
/
--checked

-- Lay danh sach BAO
CREATE OR REPLACE PROCEDURE get_storm_list(
    bao_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN bao_cursor FOR
        SELECT *
        FROM BAO b;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20016,
            'Error in get_storm_list: ' || SQLERRM);
END;
/
--checked

-- Lay thong tin chi tiet BAO
CREATE OR REPLACE PROCEDURE get_storm_info(
    bao_cursor OUT SYS_REFCURSOR,
    p_MaBao        LOG_DUONG_DI_BAO.MaBao%TYPE
)
IS
BEGIN
    OPEN bao_cursor FOR
        SELECT lddb.MaLogDuongDi, lddb.ThoiGian, DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(lddb.ViTri), 4000, 1) as ViTriWKT, lddb.MucDo
        FROM LOG_DUONG_DI_BAO lddb
        JOIN BAO b ON b.MaBao = lddb.MaBao
        WHERE b.MABAO = p_MaBao
        ORDER BY MaLogDuongDi ASC;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20017,
            'Error in get_storm_info: ' || SQLERRM);
END;
/

-- PROCEDURE XU LY
-- Tao admin
CREATE OR REPLACE PROCEDURE insert_ADMIN(
    p_USERNAME      APP_USER.USERNAME%TYPE,
    p_PASSWORD      APP_USER.PASSWORD%TYPE,
    p_HoTen         ADMIN.HoTen%TYPE,
    p_CoQuan        ADMIN.CoQuan%TYPE,
    p_CCCD          ADMIN.CCCD%TYPE
)
IS
    p_MaAdmin       ADMIN.MaAdmin%TYPE;
BEGIN
    INSERT INTO APP_USER(USERNAME, PASSWORD, ROLE)
    VALUES(p_USERNAME, p_PASSWORD, 'ADMIN');

    SELECT USER_ID
    INTO p_MaAdmin
    FROM APP_USER
    WHERE USERNAME = p_USERNAME;

    INSERT INTO ADMIN(MaAdmin, HoTen, CoQuan, CCCD)
    VALUES(p_MaAdmin, p_HoTen, p_CoQuan, p_CCCD);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20018,
            'Error in insert_ADMIN: ' || SQLERRM);
END;
/
--checked

--1. THONG TIN DANG KY 

-- DANG KY THONG TIN CHU_TAU
-- Tao CHU_TAU

-- co loi 
CREATE OR REPLACE PROCEDURE insert_CHU_TAU(
    p_USERNAME      APP_USER.USERNAME%TYPE,
    p_PASSWORD      APP_USER.PASSWORD%TYPE,
    p_HoTen         CHU_TAU.HoTen%TYPE,
    p_SDT           CHU_TAU.SDT%TYPE,
    p_DiaChi        CHU_TAU.DiaChi%TYPE,
    p_CCCD          CHU_TAU.CCCD%TYPE
)
IS
    p_MaChuTau      CHU_TAU.MaChuTau%TYPE;
BEGIN
    INSERT INTO APP_USER(USERNAME, PASSWORD)
    VALUES(p_USERNAME, p_PASSWORD);

    SELECT USER_ID
    INTO p_MaChuTau
    FROM APP_USER
    WHERE USERNAME = p_USERNAME;

    INSERT INTO CHU_TAU(MaChuTau, HoTen, SDT, DiaChi, CCCD)
    VALUES(p_MaChuTau, p_HoTen, p_SDT,p_DiaChi, p_CCCD);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20019,
            'Error in insert_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- DANG KY THONG TIN TAU_CA
-- Insert NGHE
CREATE OR REPLACE PROCEDURE insert_NGHE(
    p_TenNghe       NGHE.TenNghe%TYPE
)
IS
BEGIN
    INSERT INTO NGHE(TenNghe)
    VALUES (p_TenNghe);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Error in insert_NGHE: ' || SQLERRM);
END;

-- Insert TAU_CA
CREATE OR REPLACE PROCEDURE insert_TAU_CA(
    p_SoDangKy           TAU_CA.SoDangKy%TYPE,
    p_ChieuDai           TAU_CA.ChieuDai%TYPE,
    p_CongSuat           TAU_CA.CongSuat%TYPE,
    p_NamDongTau         TAU_CA.NamDongTau%TYPE,
    p_MaChuTau           TAU_CA.MaChuTau%TYPE,
    p_MaNgheChinh        TAU_CA.MaNgheChinh%TYPE
)
IS
    p_TrangThaiDuyetChuTau  CHU_TAU.TrangThaiDuyet%TYPE;
BEGIN
    SELECT TrangThaiDuyet
    INTO p_TrangThaiDuyetChuTau
    FROM CHU_TAU
    WHERE MaChuTau = p_MaChuTau;

    IF p_TrangThaiDuyetChuTau = 'DA DUYET' THEN
        INSERT INTO TAU_CA(SoDangKy, ChieuDai, CongSuat, NamDongTau, MaChuTau, MaNgheChinh)
        VALUES (p_SoDangKy, p_ChieuDai, p_CongSuat, p_NamDongTau, p_MaChuTau, p_MaNgheChinh);
    ELSE
        RAISE_APPLICATION_ERROR(-20021, 'Error in insert_TAU_CA: HO SO CHU TAU CHUA DUOC DUYET');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20022,
            'Error in insert_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- Insert NGHE cho TAU_CA
CREATE OR REPLACE PROCEDURE insert_TAU_NGHE(
    p_MaTauCa            TAU_NGHE.MaTauCa%TYPE,
    p_MaNghe             TAU_NGHE.MaNghe%TYPE,
    p_VungHoatDong       TAU_NGHE.VungHoatDong%TYPE
)
IS
BEGIN
    INSERT INTO TAU_NGHE(MaTauCa, MaNghe, VungHoatDong)
    VALUES (p_MaTauCa, p_MaNghe, p_VungHoatDong);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20023,
            'Error in insert_TAU_NGHE: ' || SQLERRM);
END;
/
--checked

-- DUYET THONG TIN CHU_TAU
-- Cap nhat trang thai duyet CHU_TAU
CREATE OR REPLACE PROCEDURE update_approval_status_CHU_TAU(
    p_TrangThaiDuyet    CHU_TAU.TrangThaiDuyet%TYPE,
    p_MaChuTau          CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    UPDATE CHU_TAU
    SET TrangThaiDuyet = p_TrangThaiDuyet
    WHERE MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20024,
            'Error in update_approval_status_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- DUYET THONG TIN TAU_CA
-- Cap nhat trang thai duyet TAU_CA
CREATE OR REPLACE PROCEDURE update_approval_status_TAU_CA(
    p_TrangThaiDuyet    TAU_CA.TrangThaiDuyet%TYPE,
    p_MaTauCa           TAU_CA.MaTauCa%TYPE
)
IS
BEGIN
    UPDATE TAU_CA
    SET TrangThaiDuyet = p_TrangThaiDuyet
    WHERE MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20025,
            'Error in update_approval_status_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT THONG TIN CHU_TAU
-- Update CHU_TAU
CREATE OR REPLACE PROCEDURE update_info_CHU_TAU(
    p_MaChuTau        CHU_TAU.MaChuTau%TYPE,
    p_HoTen           CHU_TAU.HoTen%TYPE,
    p_SDT             CHU_TAU.SDT%TYPE,
    p_DiaChi          CHU_TAU.DiaChi%TYPE,
    p_CCCD            CHU_TAU.CCCD%TYPE
)
IS
BEGIN
    UPDATE CHU_TAU
    SET HoTen = p_HoTen,
        SDT = p_SDT,
        DiaChi = p_DiaChi,
        CCCD = p_CCCD,
        TrangThaiDuyet = 'DANG CHO'
    WHERE MaChuTau = p_MaChuTau;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20026,
            'Error in update_info_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT THONG TIN TAU_CA
-- Update TAU_CA
CREATE OR REPLACE PROCEDURE update_info_TAU_CA(
    p_MaTauCa            TAU_CA.MaTauCa%TYPE,
    p_SoDangKy           TAU_CA.SoDangKy%TYPE,
    p_ChieuDai           TAU_CA.ChieuDai%TYPE,
    p_CongSuat           TAU_CA.CongSuat%TYPE,
    p_NamDongTau         TAU_CA.NamDongTau%TYPE,
    p_MaNgheChinh        TAU_CA.MaNgheChinh%TYPE
)
IS
BEGIN
    UPDATE TAU_CA
    SET SoDangKy = p_SoDangKy,
        ChieuDai = p_ChieuDai,
        CongSuat = p_CongSuat,
        NamDongTau = p_NamDongTau,
        TrangThaiDuyet = 'DANG CHO',
        MaNgheChinh = p_MaNgheChinh
    WHERE MaTauCa = p_MaTauCa;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20027,
            'Error in update_info_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- THEO DOI TRANG THAI DUYET CHU_TAU
-- Lay trang thai duyet CHU_TAU
CREATE OR REPLACE PROCEDURE get_approval_status_CHU_TAU(
    chu_tau_cursor OUT SYS_REFCURSOR,
    p_MaChuTau         CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN chu_tau_cursor FOR
        SELECT ct.TrangThaiDuyet
        FROM CHU_TAU ct
        WHERE ct.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20028,
            'Error in get_approval_status_CHU_TAU: ' || SQLERRM);
END;
/
--checked

-- THEO DOI TRANG THAI DUYET TAU_CA
-- Lay danh sau TAU_CA va trang thai duyet TAU_CA cua CHU_TAU
CREATE OR REPLACE PROCEDURE get_approval_status_TAU_CA(
    tau_ca_cursor OUT SYS_REFCURSOR,
    p_MaChuTau        CHU_TAU.MaChuTau%TYPE
)
IS
BEGIN
    OPEN tau_ca_cursor FOR
        SELECT tc.MaTauCa, tc.SoDangKy, tc.TrangThaiDuyet
        FROM TAU_CA tc
        WHERE tc.MaChuTau = p_MaChuTau;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20029,
            'Error in get_approval_status_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- 2.HOAT DONG DANH BAT BAT

-- DANG KY THONG TIN CHUYEN DANH BAT
-- Tao CHUYEN_DANH_BAT
CREATE OR REPLACE PROCEDURE insert_CHUYEN_DANH_BAT(
    p_NgayXuatBen       CHUYEN_DANH_BAT.NgayXuatBen%TYPE,
    p_NgayCapBen       CHUYEN_DANH_BAT.NgayCapBen%TYPE,
    p_CangDi            CHUYEN_DANH_BAT.CangDi%TYPE,
    p_CangVe            CHUYEN_DANH_BAT.CangVe%TYPE,
    p_MaTauCa           CHUYEN_DANH_BAT.MaTauCa%TYPE,
    p_MaNguTruong       CHUYEN_DANH_BAT.MaNguTruong%TYPE
)
IS
    p_TrangThaiDuyetChuTau          CHU_TAU.TrangThaiDuyet%TYPE;
    p_TrangThaiDuyetTauCa           TAU_CA.TrangThaiDuyet%TYPE;
    p_TrangThaiHoatDongTauCa        TAU_CA.TrangThaiDuyet%TYPE;
    f_HienTai                       NGU_TRUONG.SoLuongTauHienTai%TYPE;
    f_ToiDa                         NGU_TRUONG.SoLuongTauToiDa%TYPE;
BEGIN
    SELECT SoLuongTauHienTai, SoLuongTauToiDa
    INTO f_HienTai, f_ToiDa
    FROM NGU_TRUONG
    WHERE MaNguTruong = p_MaNguTruong;

    SELECT ct.TrangThaiDuyet, tc.TrangThaiDuyet, tc.TrangThaiHoatDong
    INTO p_TrangThaiDuyetChuTau, p_TrangThaiDuyetTauCa, p_TrangThaiHoatDongTauCa
    FROM TAU_CA tc 
    JOIN CHU_TAU ct ON tc.MaChuTau = ct.MaChuTau
    WHERE tc.MaTauCa = p_MaTauCa;

    IF p_TrangThaiDuyetChuTau = 'DA DUYET' AND p_TrangThaiDuyetTauCa = 'DA DUYET' AND p_TrangThaiHoatDongTauCa = 'DANG CHO|CHUA DK' AND f_HienTai <  f_ToiDa THEN
        INSERT INTO CHUYEN_DANH_BAT(
            NgayXuatBen,
            NgayCapBen,
            CangDi,
            CangVe,
            TrangThaiDuyet,
            TrangThaiHoatDong,
            MaTauCa,
            MaNguTruong
        )
        VALUES(
            p_NgayXuatBen,
            p_NgayCapBen,
            p_CangDi,
            p_CangVe,
            'DANG CHO',
            'DANG CHO',
            p_MaTauCa,
            p_MaNguTruong
        );

        UPDATE TAU_CA
        SET TrangThaiHoatDong = 'DANG CHO|DA DK'
        WHERE MaTauCa = p_MaTauCa;

        UPDATE NGU_TRUONG
        SET SoLuongTauHienTai = f_HienTai + 1
        WHERE MaNguTruong = p_MaNguTruong;
   
    ELSIF p_TrangThaiHoatDongTauCa != 'DANG CHO|CHUA DK' THEN
        RAISE_APPLICATION_ERROR(-20030, 'Error in insert_CHUYEN_DANH_BAT: TAU DA DUOC DANG KY');
    ELSIF p_KtraSoLuongTau = FALSE THEN
        RAISE_APPLICATION_ERROR(-20031, 'Error in insert_CHUYEN_DANH_BAT: SO LUONG TAU O NGU TRUONG DAT TOI DA');
    ELSE
        RAISE_APPLICATION_ERROR(-20032, 'Error in insert_CHUYEN_DANH_BAT: HO SO CHU TAU HOAC HO SO TAU CA CHUA DUOC DUYET');
    END IF;
    
    
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20033,
            'Error in insert_CHUYEN_DANH_BAT: ' || SQLERRM);
END;
/

--checked

-- DUYET THONG TIN CHUYEN DANH BAT
-- Cap nhat trang thai duyet CHUYEN_DANH_BAT
CREATE OR REPLACE PROCEDURE update_approval_status_CHUYEN_DANH_BAT(
    p_TrangThaiDuyet    CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE,
    p_MaChuyenDanhBat   CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE
)
IS
    p_MaNguTruong    CHUYEN_DANH_BAT.MaNguTruong%TYPE;
    p_MaTauCa        CHUYEN_DANH_BAT.MaTauCa%TYPE;
BEGIN
    UPDATE CHUYEN_DANH_BAT
    SET TrangThaiDuyet = p_TrangThaiDuyet
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    IF p_TrangThaiDuyet != 'DA DUYET' THEN
        SELECT MaTauCa, MaNguTruong
        INTO p_MaTauCa, p_MaNguTruong
        FROM CHUYEN_DANH_BAT
        WHERE MaChuyenDanhBat = p_MaChuyenDanhBat; 

        UPDATE TAU_CA
        SET TrangThaiHoatDong = 'DANG CHO|CHUA DK'
        WHERE MaTauCa = p_MaTauCa;

        UPDATE NGU_TRUONG
        SET SoLuongTauHienTai = SoLuongTauHienTai - 1
        WHERE MaNguTruong = p_MaNguTruong;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20034,
            'Error in update_approval_status_CHUYEN_DANH_BAT: ' || SQLERRM);
END;
/
--checked

-- GIAM SAT DANH BAT
-- Lay thong tin vi tri moi nhat cua tat ca tau
CREATE OR REPLACE PROCEDURE get_newest_location_info_all(
    p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT MaTauCa, ThoiGian, ViTriWKT, VanToc, HuongDiChuyen
        FROM (
            SELECT tc.MaTauCa, lht.ThoiGian,
                DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(lht.ViTri), 4000, 1) AS ViTriWKT,
                lht.VanToc, lht.HuongDiChuyen,
                ROW_NUMBER() OVER (
                PARTITION BY tc.MaTauCa
                ORDER BY lht.ThoiGian DESC
                ) AS rn
            FROM TAU_CA tc
            JOIN CHUYEN_DANH_BAT cdb ON cdb.MaTauCa = tc.MaTauCa
            JOIN LOG_HAI_TRINH lht ON lht.MaChuyenDanhBat = cdb.MaChuyenDanhBat
        ) sub
        WHERE sub.rn = 1;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20035,
            'Error in get_newest_location_info_all: ' || SQLERRM);
END;
/
--checked

-- GIAM SAT TAU_CA TRONG DOI TAU
-- Lay thong tin vi tri moi nhat cua cac tau trong doi tau
CREATE OR REPLACE PROCEDURE get_newest_location_info_owner(
    p_cursor OUT SYS_REFCURSOR,
    p_MaChuTau      TAU_CA.MaChuTau%TYPE
)
IS
BEGIN
  OPEN p_cursor FOR
    SELECT MaTauCa, ThoiGian, ViTriWKT, VanToc, HuongDiChuyen
    FROM (
        SELECT tc.MaTauCa, lht.ThoiGian,
            DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(lht.ViTri), 4000, 1) AS ViTriWKT,
            lht.VanToc, lht.HuongDiChuyen,
            ROW_NUMBER() OVER (
            PARTITION BY tc.MaTauCa
            ORDER BY lht.ThoiGian DESC
            ) AS rn
        FROM TAU_CA tc
        JOIN CHUYEN_DANH_BAT cdb ON cdb.MaTauCa = tc.MaTauCa
        JOIN LOG_HAI_TRINH lht ON lht.MaChuyenDanhBat = cdb.MaChuyenDanhBat
        WHERE tc.MaChuTau = p_MaChuTau
    ) sub
    WHERE sub.rn = 1;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20036,
            'Error in get_newest_location_info_owner: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT TRANG THAI ROI / CAP CANG
-- Cap nhat trang thai roi cang
CREATE OR REPLACE PROCEDURE update_working_status_depart(
    p_MaTauCa   CHUYEN_DANH_BAT.MaTauCa%TYPE,
    p_CangDi    CHUYEN_DANH_BAT.CangDi%TYPE
)
IS
    p_MaChuyenDanhBat               CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    p_TrangThaiHoatDongTauCa        TAU_CA.TrangThaiHoatDong%TYPE;
    p_TrangThaiDuyetCDB             CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE;
BEGIN
    SELECT TrangThaiHoatDong
    INTO p_TrangThaiHoatDongTauCa
    FROM TAU_CA
    WHERE MaTauCa = p_MaTauCa;

    IF p_TrangThaiHoatDongTauCa = 'DANG CHO|CHUA DK' THEN
        RAISE_APPLICATION_ERROR(-20037, 'Error in update_working_status_depart: TAU CHUA DANG KY CHUYEN DANH BAT');
    ELSIF p_TrangThaiHoatDongTauCa = 'DANG HOAT DONG' THEN
        RAISE_APPLICATION_ERROR(-20038, 'Error in update_working_status_depart: TAU DANG HOAT DONG, KHONG THE DUNG CHUC NANG NAY');
    END IF;

    SELECT MaChuyenDanhBat
    INTO p_MaChuyenDanhBat
    FROM CHUYEN_DANH_BAT
    WHERE MaTauCa = p_MaTauCa AND TrangThaiHoatDong = 'DANG CHO';

    SELECT TrangThaiDuyet
    INTO p_TrangThaiDuyetCDB
    FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    IF p_TrangThaiDuyetCDB = 'DANG CHO' THEN
        RAISE_APPLICATION_ERROR(-20039, 'Error in update_working_status_depart: CHUYEN DANH BAT CHUA DUOC DUYET');
    ELSIF p_TrangThaiDuyetCDB = 'TU CHOI' THEN
        RAISE_APPLICATION_ERROR(-20040, 'Error in update_working_status_depart: CHUYEN DANH BAT BI TU CHOI');
    END IF;

    UPDATE TAU_CA
    SET TrangThaiHoatDong = 'DANG HOAT DONG'
    WHERE MaTauCa = p_MaTauCa;

    UPDATE CHUYEN_DANH_BAT
    SET TrangThaiHoatDong = 'DANG DANH BAT',
        CangDi = p_CangDi,
        NgayXuatBen = SYSDATE
    WHERE MaTauCa = p_MaTauCa;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20041,
            'Error in update_working_status_depart: ' || SQLERRM);
END;
/
--checked

-- Cap nhat trang thai cap cang
CREATE OR REPLACE PROCEDURE update_working_status_dock(
    p_MaTauCa   CHUYEN_DANH_BAT.MaTauCa%TYPE,
    p_CangVe    CHUYEN_DANH_BAT.CangVe%TYPE
)
IS
    p_MaChuyenDanhBat               CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    p_TrangThaiHoatDongTauCa        TAU_CA.TrangThaiHoatDong%TYPE;
    p_TrangThaiDuyetCDB             CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE;
    p_MaNguTruong                   CHUYEN_DANH_BAT.MaNguTruong%TYPE;
BEGIN
    SELECT TrangThaiHoatDong
    INTO p_TrangThaiHoatDongTauCa
    FROM TAU_CA
    WHERE MaTauCa = p_MaTauCa;

    IF p_TrangThaiHoatDongTauCa = 'DANG HOAT DONG' THEN
        SELECT MaChuyenDanhBat, MaNguTruong
        INTO p_MaChuyenDanhBat, p_MaNguTruong
        FROM CHUYEN_DANH_BAT
        WHERE MaTauCa = p_MaTauCa AND TrangThaiHoatDong = 'DANG DANH BAT';

        UPDATE CHUYEN_DANH_BAT
        SET TrangThaiHoatDong = 'HOAN THANH',
            CangVe = p_CangVe,
            NgayCapBen = SYSDATE
        WHERE MaTauCa = p_MaTauCa;

        UPDATE TAU_CA
        SET TrangThaiHoatDong = 'DANG CHO|CHUA DK'
        WHERE MaTauCa = p_MaTauCa;

        UPDATE NGU_TRUONG
        SET SoLuongTauHienTai = SoLuongTauHienTai - 1
        WHERE MaNguTruong = p_MaNguTruong;
    ELSE 
        RAISE_APPLICATION_ERROR(-20042, 'Error in update_working_status_dock: TAU HIEN TAI KHONG HOAT DONG');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20043,
            'Error in update_working_status_dock: ' || SQLERRM);
END;
/
--checked

-- CAP NHAT NHAT KY DANH BAT

-- Insert ME_CA
CREATE OR REPLACE PROCEDURE insert_ME_CA(
    p_MaChuyenDanhBat       IN ME_CA.MaChuyenDanhBat%TYPE,
    p_ThoiGianThaLuoi       IN ME_CA.ThoiGianThaLuoi%TYPE,
    p_ThoiGianKeoLuoi       IN ME_CA.ThoiGianKeoLuoi%TYPE,
    p_ViTriKeoLuoi          IN VARCHAR2 -- WKT format: 'POINT(x y)'
)
IS
    v_ViTriKeoLuoi SDO_GEOMETRY;
BEGIN
    
    BEGIN
        v_ViTriKeoLuoi := SDO_UTIL.FROM_WKTGEOMETRY(p_ViTriKeoLuoi);
        v_ViTriKeoLuoi.SDO_SRID := 4326;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20044, 'Error in insert_ME_CA: WKT không hợp lệ. ' || SQLERRM);
    END;

    
    INSERT INTO ME_CA (
        MaChuyenDanhBat,
        ThoiGianThaLuoi,
        ThoiGianKeoLuoi,
        ViTriKeoLuoi
    ) VALUES (
        p_MaChuyenDanhBat,
        p_ThoiGianThaLuoi,
        p_ThoiGianKeoLuoi,
        v_ViTriKeoLuoi
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20045, 'Error in insert_ME_CA: ' || SQLERRM);
END insert_ME_CA;
/

--checked

--Insert CHI TIET ME_CA
CREATE OR REPLACE PROCEDURE insert_DANHBAT_THUYSAN(
    p_MaChuyenDanhBat       CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE,
    p_MaMeCa                ME_CA.MaMeCa%TYPE,
    p_MaThuySan             THUY_SAN.MaThuySan%TYPE,
    p_KhoiLuong             DANHBAT_THUYSAN.KhoiLuong%TYPE
)
IS
BEGIN
    INSERT INTO DANHBAT_THUYSAN(MaChuyenDanhBat, MaMeCa, MaThuySan, KhoiLuong)
    VALUES (p_MaChuyenDanhBat, p_MaMeCa, p_MaThuySan, p_KhoiLuong);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20045,
            'Error in insert_DANHBAT_THUYSAN: ' || SQLERRM);
END;
/

--checked

-- THEO DOI HAI TRINH
-- Lay danh sach LOG toa do
CREATE OR REPLACE PROCEDURE get_log_list_CHUYEN_DANH_BAT(
    p_cursor OUT SYS_REFCURSOR,
    p_MaChuyenDanhBat   CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT lht.MaLogHaiTrinh, lht.ThoiGian, lht.ViTri, lht.VanToc, lht.HuongDiChuyen
        FROM LOG_HAI_TRINH lht
        WHERE lht.MaChuyenDanhBat = p_MaChuyenDanhBat;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20046,
            'Error in get_log_list_CHUYEN_DANH_BAT: ' || SQLERRM);
END;
/

-- CAP NHAT VI TRI TAU
-- Them 1 diem toa do vao LOG
CREATE OR REPLACE PROCEDURE insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT(
    p_MaChuyenDanhBat     LOG_HAI_TRINH.MaChuyenDanhBat%TYPE,
    p_ThoiGian            LOG_HAI_TRINH.ThoiGian%TYPE,
    p_ViTri               VARCHAR2,
    p_VanToc              LOG_HAI_TRINH.VanToc%TYPE,
    p_HuongDiChuyen       LOG_HAI_TRINH.HuongDiChuyen%TYPE
)
IS
    v_exists NUMBER; 
    v_NgayXuatBen CHUYEN_DANH_BAT.NgayXuatBen%TYPE;
    v_geom SDO_GEOMETRY;
BEGIN
    SELECT NgayXuatBen
        INTO v_NgayXuatBen
        FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    SELECT COUNT(*) 
        INTO v_exists
        FROM CHUYEN_DANH_BAT
    WHERE MaChuyenDanhBat = p_MaChuyenDanhBat;

    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20047, 
            'insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT: Chuyen danh bat khong ton tai.');
    ELSIF p_ThoiGian < v_NgayXuatBen OR p_ThoiGian > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20047, 
            'insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT: ThoiGian khong dung');
    END IF;

    -- Chuyển WKT sang SDO_GEOMETRY và gán SRID
    v_geom := SDO_UTIL.FROM_WKTGEOMETRY(p_ViTri);
    v_geom.SDO_SRID := 4326;

    INSERT INTO LOG_HAI_TRINH(MaChuyenDanhBat, ThoiGian, ViTri, VanToc, HuongDiChuyen)
    VALUES (p_MaChuyenDanhBat, p_ThoiGian, v_geom, p_VanToc, p_HuongDiChuyen);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20048,
            'Error in insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT: ' || SQLERRM);
END;

--checked

-- TRUY XUAT NHAT KY DANH BAT
-- Lay nhat ky danh bat
CREATE OR REPLACE PROCEDURE get_fishing_diary(
    thong_tin_tau_cursor OUT SYS_REFCURSOR,
    thong_tin_danh_bat_cursor OUT SYS_REFCURSOR,
    p_MaChuyenDanhBat          CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE 
)
IS
BEGIN
    OPEN thong_tin_tau_cursor FOR 
        SELECT 
            ct.HoTen,
            tc.MaTauCa, tc.SoDangKy, tc.LoaiTau, tc.ChieuDai, tc.CongSuat,
            nghe_chinh.TenNghe,
            cdb.MaChuyenDanhBat, cdb.NgayXuatBen, cdb.NgayCapBen, cdb.CangDi, cdb.CangVe,
            nghe_chinh.TenNghe
        FROM CHUYEN_DANH_BAT cdb
        JOIN TAU_CA tc ON tc.MaTauCa = cdb.MaTauCa
        JOIN CHU_TAU ct ON ct.MaChuTau = tc.MaChuTau
        JOIN NGHE nghe_chinh ON nghe_chinh.MaNghe = tc.MaNgheChinh
        JOIN TAU_NGHE tau_nghe ON tau_nghe.MaTauCa = tc.MaTauCa
        WHERE cdb.MaChuyenDanhBat = p_MaChuyenDanhBat;

    OPEN thong_tin_danh_bat_cursor FOR 
        SELECT 
            mc.MaMeCa, 
            mc.KhoiLuongMeCa, 
            mc.ThoiGianThaLuoi, 
            mc.ThoiGianKeoLuoi, 
            DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(mc.ViTriKeoLuoi), 4000, 1) AS ViTriWKT,
            LISTAGG(ts.TenLoaiThuySan || ': ' || dbts.KhoiLuong || 'kg', ', ') 
                WITHIN GROUP (ORDER BY ts.TenLoaiThuySan ASC) AS ChiTietMeCa
        FROM ME_CA mc
        JOIN DANHBAT_THUYSAN dbts ON dbts.MaMeCa = mc.MaMeCa AND dbts.MaChuyenDanhBat = mc.MaChuyenDanhBat
        JOIN THUY_SAN ts ON ts.MaThuySan = dbts.MaThuySan
        WHERE mc.MaChuyenDanhBat = p_MaChuyenDanhBat
        GROUP BY             
            mc.MaMeCa, 
            mc.KhoiLuongMeCa, 
            mc.ThoiGianThaLuoi, 
            mc.ThoiGianKeoLuoi, 
            DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(mc.ViTriKeoLuoi), 4000, 1);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20049,
            'Error in get_fishing_diary: ' || SQLERRM);
END;
/
--checked

-- Insert VI_PHAM
CREATE OR REPLACE PROCEDURE insert_VI_PHAM(
    p_MaChuyenDanhBat   IN VI_PHAM.MaChuyenDanhBat%TYPE,
    p_ThoiGian          IN VI_PHAM.ThoiGian%TYPE,
    p_ViTri_WKT         IN VARCHAR2,
    p_MoTa              IN VI_PHAM.MoTa%TYPE
)
IS
    v_ViTri SDO_GEOMETRY;
BEGIN
    -- 1) Chuyển WKT sang SDO_GEOMETRY và gán SRID
    BEGIN
        v_ViTri := SDO_UTIL.FROM_WKTGEOMETRY(p_ViTri_WKT);
        v_ViTri.SDO_SRID := 4326;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20050,
                'Error in insert_VI_PHAM: WKT không hợp lệ. ' || SQLERRM);
    END;

    -- 2) Thêm dữ liệu vào bảng VI_PHAM
    INSERT INTO VI_PHAM (
        MaChuyenDanhBat,
        ThoiGian,
        ViTri,
        MoTa
    ) VALUES (
        p_MaChuyenDanhBat,
        p_ThoiGian,
        v_ViTri,
        p_MoTa
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20066,
            'Error in insert_VI_PHAM: ' || SQLERRM
        );
END insert_VI_PHAM;
/
--checked

-- Cap nhat MoTa cua VI_PHAM
CREATE OR REPLACE PROCEDURE update_description_VI_PHAM(
    p_MaViPham          VI_PHAM.MaViPham%TYPE,
    p_MoTa              VI_PHAM.MoTa%TYPE
)
IS
BEGIN
    UPDATE VI_PHAM
    SET MoTa = p_MoTa
    WHERE MaViPham = p_MaViPham;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20051,
            'Error in update_description_VI_PHAM: ' || SQLERRM);
END;
/
--checked

--3.NGU TRUONG

-- THEM THONG TIN NGU TRUONG
-- insert_NGU_TRUONG
CREATE OR REPLACE PROCEDURE insert_NGU_TRUONG(
    p_TenNguTruong      IN NGU_TRUONG.TenNguTruong%TYPE,
    p_ViTri_WKT         IN CLOB,
    p_SoLuongTauToiDa   IN NGU_TRUONG.SoLuongTauToiDa%TYPE
)
IS
    v_WktShort  VARCHAR2(32767);
    v_ViTri     SDO_GEOMETRY;
BEGIN
    -- 1. Lấy chuỗi WKT (tối đa 32767 ký tự) từ CLOB
    v_WktShort := DBMS_LOB.SUBSTR(p_ViTri_WKT, 32767, 1);

    -- 2. Chuyển WKT thành SDO_GEOMETRY (SRID ban đầu = NULL)
    BEGIN
        v_ViTri := SDO_UTIL.FROM_WKTGEOMETRY(v_WktShort);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20052,
                'Error in insert_NGU_TRUONG: WKT không hợp lệ. ' || SQLERRM
            );
    END;

    -- 3. Gán SRID = 4326 cho đối tượng geometry vừa tạo
    v_ViTri.SDO_SRID := 4326;

    -- 4. Thực hiện chèn vào bảng (MaNguTruong do trigger tự sinh)
    INSERT INTO NGU_TRUONG (
      TenNguTruong,
      ViTri,
      SoLuongTauToiDa
    )
    VALUES (
      p_TenNguTruong,
      v_ViTri,
      p_SoLuongTauToiDa
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20053,
            'Error in insert_NGU_TRUONG: ' || SQLERRM
        );
END insert_NGU_TRUONG;
/
--checked

-- XEM THONG TIN NGU TRUONG
-- Lay thong tin NGU_TRUONG
CREATE OR REPLACE PROCEDURE get_fishery_info(
    ngu_truong_cursor OUT SYS_REFCURSOR,
    p_MaNguTruong       NGU_TRUONG.MaNguTruong%TYPE
)
IS
BEGIN

    OPEN ngu_truong_cursor FOR
        SELECT ng.TenNguTruong, DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(ng.ViTri), 32767, 1) AS ViTriWKT, ng.SoLuongTauToiDa, ng.SoLuongTauHienTai
        FROM NGU_TRUONG ng 
        WHERE ng.MaNguTruong = p_MaNguTruong;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20054,
            'Error in get_fishery_info: ' || SQLERRM);
END;
/
--checked

--4. THONG KE
-- VI_PHAM
-- Lay danh sach VI_PHAM
CREATE OR REPLACE PROCEDURE get_list_VI_PHAM(
    vi_pham_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN vi_pham_cursor FOR
        SELECT vp.MaViPham, vp.MaChuyenDanhBat, cdb.MaTauCa, vp.ThoiGian, DBMS_LOB.SUBSTR(SDO_UTIL.TO_WKTGEOMETRY(vp.ViTri), 32767, 1) AS ViTriWKT, vp.MoTa
        FROM VI_PHAM vp
        JOIN CHUYEN_DANH_BAT cdb ON cdb.MaChuyenDanhBat = vp.MaChuyenDanhBat; 

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20055,
            'Error in get_list_VI_PHAM: ' || SQLERRM);
END;
/
--checked

-- THONG KE SO LUONG VI PHAM THEO TAU
CREATE OR REPLACE PROCEDURE statistics_VI_PHAM_by_TAU_CA(
    vi_pham_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN vi_pham_cursor FOR
        SELECT tc.MaTauCa, tc.SoDangKy, count(vp.MaViPham) AS SoLuongLoiViPham
        FROM TAU_CA tc
        JOIN CHUYEN_DANH_BAT cdb ON cdb.MaTauCa = tc.MaTauCa
        LEFT JOIN VI_PHAM vp ON vp.MaChuyenDanhBat = cdb.MaChuyenDanhBat
        GROUP BY tc.MaTauCa, tc.SoDangKy
        ORDER BY SoLuongLoiViPham DESC;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20056,
            'Error in statistics_VI_PHAM_by_TAU_CA: ' || SQLERRM);
END;
/
--checked

-- THUY SAN
-- THONG KE SAN LUONG THEO LOAI THUY SAN
CREATE OR REPLACE PROCEDURE statistics_seafood_output_by_species(
    thuy_san_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN thuy_san_cursor FOR
        SELECT ts.MaThuySan, ts.TenLoaiThuySan, SUM(dbts.KhoiLuong) AS TongKhoiLuong
        FROM THUY_SAN ts
        JOIN DANHBAT_THUYSAN dbts ON dbts.MaThuySan = ts.MaThuySan
        GROUP BY ts.MaThuySan, ts.TenLoaiThuySan;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20057,
            'Error in statistics_seafood_output_by_species: ' || SQLERRM);
END;
/
--checked

-- BAO
-- THONG KE SO LUONG BAO THEO NAM
CREATE OR REPLACE PROCEDURE statistics_storm_count_by_year(
    bao_cursor OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN bao_cursor FOR
        SELECT EXTRACT(YEAR FROM lddb.ThoiGian) AS Nam,
                COUNT(DISTINCT b.MaBao) AS SoLuongBao
        FROM BAO b
        JOIN LOG_DUONG_DI_BAO lddb ON lddb.MaBao = b.MaBao
        GROUP BY EXTRACT(YEAR FROM lddb.ThoiGian)
        ORDER BY Nam;

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20058,
            'Error in statistics_storm_count_by_year: ' || SQLERRM);
END;
/
--checked

--5. KHI TUONG THUY VAN
-- insert THOI_TIET
CREATE OR REPLACE PROCEDURE insert_THOI_TIET(
    p_ThoiGianDuBao     THOI_TIET.ThoiGianDuBao%TYPE,
    p_KhuVucAnhHuong    THOI_TIET.KhuVucAnhHuong%TYPE,
    p_ChiTietDuBao      THOI_TIET.ChiTietDuBao%TYPE
)
IS
BEGIN
    INSERT INTO THOI_TIET(ThoiGianDuBao, KhuVucAnhHuong, ChiTietDuBao)
    VALUES (p_ThoiGianDuBao, p_KhuVucAnhHuong, p_ChiTietDuBao);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20059,
            'Error in insert_THOI_TIET: ' || SQLERRM);
END;
/
--checked

-- insert BAO
CREATE OR REPLACE PROCEDURE insert_BAO(
    p_TenBao    BAO.TenBao%TYPE
)
IS
BEGIN
    INSERT INTO BAO(TENBAO)
    VALUES (p_TenBao);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20060,
            'Error in insert_BAO: ' || SQLERRM);
END;
/
--checked

-- insert LOG_DUONG_DI_BAO
CREATE OR REPLACE PROCEDURE insert_LOG_DUONG_DI_BAO(
    p_MaBao           LOG_DUONG_DI_BAO.MaBao%TYPE,
    p_ThoiGian        LOG_DUONG_DI_BAO.ThoiGian%TYPE,
    p_ViTriWKT        VARCHAR2,
    p_MucDo           LOG_DUONG_DI_BAO.MucDo%TYPE
)
IS
    v_ViTri SDO_GEOMETRY;
BEGIN
    BEGIN
        v_ViTri := SDO_UTIL.FROM_WKTGEOMETRY(p_ViTriWKT);
        v_ViTri.SDO_SRID := 4326;

        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20061, 'Error in insert_LOG_DUONG_DI_BAO:  WKT không hợp lệ, '||SQLERRM);
    END;
    
    INSERT INTO LOG_DUONG_DI_BAO(MaBao, ThoiGian, ViTri, MucDo)
        VALUES (p_MaBao, p_ThoiGian, v_ViTri, p_MucDo);

EXCEPTION
    WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20062,
            'Error in insert_LOG_DUONG_DI_BAO: ' || SQLERRM);
END;
/
--checked

-- VI. CREATE FUNCTION
--  Kiem tra dang nhap
CREATE OR REPLACE FUNCTION Fn_dang_nhap(
    p_username      APP_USER.USERNAME%TYPE,
    p_password      APP_USER.PASSWORD%TYPE
) RETURN NVARCHAR2
IS
    f_user_id NVARCHAR2(20);
BEGIN
    SELECT USER_ID
    INTO f_user_id
    FROM APP_USER
    WHERE USERNAME = p_username AND PASSWORD = p_password;

    RETURN USER_ID;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;

    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20063,
                'Error in Fn_dang_nhap: ' || SQLERRM);
END;
/
--checked

-- VII. TEST CASE

--Lay danh sach tau cua chu tau
VAR c REFCURSOR;
EXEC Hien_thi_danh_sach_tau_ca_cua_chu_tau(:c, 'USER01');
PRINT c;


--TEST insert du lieu va trigger
--da test procedure insert_NGU_TRUONG
INSERT INTO APP_USER (USERNAME, PASSWORD, ROLE)
VALUES ('admin1', 'passAdmin', 'ADMIN');

INSERT INTO APP_USER (USERNAME, PASSWORD, ROLE)
VALUES ('chutau1', 'passChuTau', 'CHUTAU');

SELECT * 
FROM APP_USER;

INSERT INTO ADMIN (MaAdmin, HoTen, CoQuan, CCCD)
VALUES ('USER1', 'Nguyễn Văn A', 'Bộ Tài nguyên Môi trường', '123456789');

INSERT INTO CHU_TAU (MaChuTau, HoTen, SDT, DiaChi, CCCD, TrangThaiDuyet)
VALUES ('USER2', 'Trần Thị B', '0987654321', 'Hải Phòng', '987654321', 'DA DUYET');

select *
from CHU_TAU;

select *
from ADMIN;

INSERT INTO NGHE (TenNghe) VALUES ('Cá biển');
INSERT INTO NGHE (TenNghe) VALUES ('Cá sông');

select *
from NGHE;

INSERT INTO TAU_CA (
  SoDangKy, LoaiTau, ChieuDai, CongSuat, NamDongTau,
  TrangThaiDuyet, TrangThaiHoatDong, MaChuTau, MaNgheChinh
) VALUES (
  'DK001', 'Tàu đánh cá xa bờ', 30.5, 120.0, 2018,
  'DA DUYET', 'DANG HOAT DONG', 'USER2', 'NGHE1'
);

select * 
from TAU_CA;

INSERT INTO TAU_NGHE (MaTauCa, MaNghe, VungHoatDong)
VALUES ('TC1', 'NGHE2', 'Vịnh Hạ Long');

select *
from TAU_NGHE;


INSERT INTO NGU_TRUONG (
  TenNguTruong,
  ViTri,
  SoLuongTauHienTai,
  SoLuongTauToiDa
) VALUES (
  'Ngư trường A',
  -- Khởi tạo SDO_GEOMETRY với SRID = 4326
  SDO_GEOMETRY(
    2003,             -- SDO_GTYPE: 2003 nghĩa là POLYGON
    4326,             -- SDO_SRID
    NULL,             -- SDO_POINT (NULL vì đây là POLYGON, không dùng point)
    SDO_ELEM_INFO_ARRAY(1,1003,1),
    SDO_ORDINATE_ARRAY(
      0, 0,
      0, 10,
      10, 10,
      10, 0,
      0, 0
    )
  ),
  0,      -- SoLuongTauHienTai mặc định = 0
  1000    -- SoLuongTauToiDa
);
COMMIT;


select *
from NGU_TRUONG;


select *
from NGU_TRUONG;

SELECT 
  MaNguTruong,
  TenNguTruong,
  SDO_UTIL.TO_WKTGEOMETRY(ViTri) AS ViTri_WKT,
  SoLuongTauHienTai,
  SoLuongTauToiDa
FROM NGU_TRUONG;

SELECT MaNguTruong,
  TenNguTruong,
  SUBSTR(
    SDO_UTIL.TO_WKTGEOMETRY(ViTri), 
    INSTR(SDO_UTIL.TO_WKTGEOMETRY(ViTri),'((') + 1,
    INSTR(SDO_UTIL.TO_WKTGEOMETRY(ViTri),'))') 
    - INSTR(SDO_UTIL.TO_WKTGEOMETRY(ViTri),'((') - 1
  ) AS ToaDoOnly
FROM NGU_TRUONG;



INSERT INTO CHUYEN_DANH_BAT (
  NgayXuatBen, NgayCapBen, CangDi, CangVe,
  TongKhoiLuong, TrangThaiDuyet, TrangThaiHoatDong, MaTauCa, MaNguTruong
) VALUES (
  TO_DATE('2025-06-01','YYYY-MM-DD'),
  TO_DATE('2025-06-05','YYYY-MM-DD'),
  'Cảng Hải Phòng',
  'Cảng Đà Nẵng',
  0,
  'DANG CHO',
  'DANG CHO',
  'TC1',
  'NT1'
);

select *
from CHUYEN_DANH_BAT;

--test procedure insert_NGU_TRUONG
BEGIN
  -- Thêm ngư trường với WKT hợp lệ
  insert_NGU_TRUONG(
    'Ngư trường Test 1',
    'POLYGON((2 2, 2 4, 4 4, 4 2, 2 2))',  -- WKT mô tả hình vuông
    5                                      -- Số lượng tàu tối đa
  );
  COMMIT;
END;
/

INSERT INTO LOG_HAI_TRINH (
  MaChuyenDanhBat, ThoiGian, ViTri, VanToc, HuongDiChuyen
) VALUES (
  'CDP2',
  SYSTIMESTAMP,
  SDO_GEOMETRY(
    2001, 
    4326,
    SDO_POINT_TYPE(5,5,NULL),
    NULL, NULL
  ),
  8.5,
  'Đông Nam'
);


select *
from LOG_HAI_TRINH;

SELECT * FROM VI_PHAM;


INSERT INTO THUY_SAN (TenLoaiThuySan) VALUES ('Ca thu');

SELECT * FROM THUY_SAN;



INSERT INTO ME_CA (
  MaChuyenDanhBat, KhoiLuongMeCa, ThoiGianThaLuoi, ThoiGianKeoLuoi, ViTriKeoLuoi
) VALUES (
  'CDP2',
  0,
  TO_TIMESTAMP('2025-06-02 06:00:00','YYYY-MM-DD HH24:MI:SS'),
  TO_TIMESTAMP('2025-06-02 07:30:00','YYYY-MM-DD HH24:MI:SS'),
  SDO_GEOMETRY(
    2001, NULL,
    SDO_POINT_TYPE(6,6,NULL),
    NULL, NULL
  )
);


 SELECT * FROM ME_CA;

 INSERT INTO DANHBAT_THUYSAN (MaThuySan, MaMeCa, MaChuyenDanhBat, KhoiLuong)
VALUES ('TS1', 1, 'CDP2', 150.75);

INSERT INTO DANHBAT_THUYSAN (MaThuySan, MaMeCa, MaChuyenDanhBat, KhoiLuong)
VALUES ('TS1', 2, 'CDP2', 150);

DESC DANHBAT_THUYSAN;
select * from DANHBAT_THUYSAN;

SELECT KhoiLuongMeCa FROM ME_CA WHERE MaMeCa=1 AND MaChuyenDanhBat='CDP2';
SELECT TongKhoiLuong FROM CHUYEN_DANH_BAT WHERE MaChuyenDanhBat='CDP2';

INSERT INTO THOI_TIET (KhuVucAnhHuong, ChiTietDuBao)
VALUES ('Vịnh Bắc Bộ', 'Tối nay gió mạnh cấp 4, sóng cao 1-2m');


SELECT * FROM THOI_TIET;

INSERT INTO BAO (TenBao) VALUES ('Bao YAGI');

INSERT INTO LOG_DUONG_DI_BAO (
  MaBao, ThoiGian, ViTri, MucDo
) VALUES (
  'BAO1',
  SYSTIMESTAMP,
  SDO_GEOMETRY(
    2001, NULL,
    SDO_POINT_TYPE(1,1,NULL),
    NULL, NULL
  ),
  3
);

SELECT * FROM LOG_DUONG_DI_BAO WHERE MaBao='BAO1';

-- test procedure 
--tao admin
BEGIN
  insert_ADMIN(
    p_USERNAME => 'admin22',
    p_PASSWORD => 'Abc@123',
    p_HoTen    => 'Nguyễn Văn A',
    p_CoQuan   => 'Sở Nông nghiệp',
    p_CCCD     => '012345678901'
  );

END;
/

BEGIN
  insert_CHU_TAU(
    p_USERNAME => 'ct_user1',                 
    p_PASSWORD => 'Pass@123',                 
    p_HoTen    => N'Nguyễn Văn A',            
    p_SDT      => N'0912345678',              
    p_DiaChi   => N'123 Đường Lê Lợi, Quận 1', 
    p_CCCD     => N'012345678901'             
  );
END;
/
select * from APP_USER;
select * from CHU_TAU;

BEGIN
  insert_TAU_CA(
    p_SoDangKy     => 'TAU001',
    p_ChieuDai     => 15.5,
    p_CongSuat     => 200,
    p_NamDongTau   => 2020,
    p_MaChuTau     => 'USER2',
    p_MaNgheChinh  => 'NGHE1'
  );
END;
/

select * from TAU_CA;
BEGIN
  insert_TAU_NGHE(
    p_MaTauCa      => 'TC1',
    p_MaNghe       => 'NGHE1',
    p_VungHoatDong => N'Vịnh Bắc Bộ'
  );
END;
/
select * from TAU_NGHE;

BEGIN
    update_approval_status_CHU_TAU(
        p_TrangThaiDuyet => 'DA_DUYET',
        p_MaChuTau       => 'CT001'  
    );
END;
/

select * from CHU_TAU;

BEGIN
    update_approval_status_CHU_TAU(
        p_TrangThaiDuyet => 'DA DUYET',
        p_MaChuTau       => 'USER7'  
    );
END;
/

BEGIN
    update_approval_status_TAU_CA(
        p_TrangThaiDuyet => 'DANG CHO',
        p_MaTauCa        => 'TC1'  
    );
END;
/
select * from TAU_CA;


BEGIN
    update_info_CHU_TAU(
        p_MaChuTau => 'USER2',
        p_HoTen    => 'Nguyễn Văn A',
        p_SDT      => '0912345678',
        p_DiaChi   => 'Quận Lê Chân, Hải Phòng',
        p_CCCD     => '123456789012'
    );
END;
/

BEGIN
    update_info_TAU_CA(
        p_MaTauCa      => 'TC1',
        p_SoDangKy     => 'HP-12345-XYZ',
        p_ChieuDai     => 18.5,
        p_CongSuat     => 350,
        p_NamDongTau   => 2020,
        p_MaNgheChinh  => 'NGHE1'
    );
END;
/


DECLARE
    v_cursor SYS_REFCURSOR;
    v_trang_thai_duyet CHU_TAU.TrangThaiDuyet%TYPE;
BEGIN
    get_approval_status_CHU_TAU(v_cursor, 'USER7'); 

    FETCH v_cursor INTO v_trang_thai_duyet;
    DBMS_OUTPUT.PUT_LINE('Trạng thái duyệt của chủ tàu: ' || v_trang_thai_duyet);

    CLOSE v_cursor;
END;
/

DECLARE
    v_cursor SYS_REFCURSOR;
    v_MaTauCa TAU_CA.MaTauCa%TYPE;
    v_SoDangKy TAU_CA.SoDangKy%TYPE;
    v_TrangThaiDuyet TAU_CA.TrangThaiDuyet%TYPE;
BEGIN
    get_approval_status_TAU_CA(v_cursor, 'USER2'); 

    LOOP
        FETCH v_cursor INTO v_MaTauCa, v_SoDangKy, v_TrangThaiDuyet;
        EXIT WHEN v_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('Tàu: ' || v_MaTauCa || ' | Số ĐK: ' || v_SoDangKy || ' | Trạng thái: ' || v_TrangThaiDuyet);
    END LOOP;

    CLOSE v_cursor;
END;
/



select * from CHUYEN_DANH_BAT;
-- Lay danh sach CHUYEN_DANH_BAT

BEGIN
    insert_CHUYEN_DANH_BAT(
        TO_DATE('2025-06-01', 'YYYY-MM-DD'),   -- NgayXuatBen
        TO_DATE('2025-06-07', 'YYYY-MM-DD'),   -- NgayCapBen
        'Cảng Hòn Rớ',                          -- CangDi
        'Cảng Phú Quý',                         -- CangVe
        'TC1',                               -- MaTauCa (đảm bảo có trong bảng TAU_CA)
        'NT1'                                 -- MaNguTruong (đảm bảo có trong bảng NGU_TRUONG)
    );
END;
/

BEGIN
  update_approval_status_CHUYEN_DANH_BAT(
    p_TrangThaiDuyet    => 'TU CHOI',
    p_MaChuyenDanhBat   => 'CDP2'
  );
END;
/


BEGIN
  update_approval_status_CHUYEN_DANH_BAT(
    p_TrangThaiDuyet    => 'DA DUYET',
    p_MaChuyenDanhBat   => 'CDP2'
  );
END;
/

DECLARE
  c_all SYS_REFCURSOR;
  v_MaTauCa       TAU_CA.MaTauCa%TYPE;
  v_ThoiGian      LOG_HAI_TRINH.ThoiGian%TYPE;
  v_ViTriWKT      CLOB;
  v_VanToc        LOG_HAI_TRINH.VanToc%TYPE;
  v_HuongDiChuyen LOG_HAI_TRINH.HuongDiChuyen%TYPE;
BEGIN
  -- Mở cursor
  get_newest_location_info_all(p_cursor => c_all);

  DBMS_OUTPUT.PUT_LINE('MaTauCa | ThoiGian            | ViTriWKT (gần đúng) | VanToc | HuongDiChuyen');
  DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------');
  LOOP
    FETCH c_all INTO v_MaTauCa, v_ThoiGian, v_ViTriWKT, v_VanToc, v_HuongDiChuyen;
    EXIT WHEN c_all%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(
      v_MaTauCa || ' | ' ||
      TO_CHAR(v_ThoiGian, 'YYYY-MM-DD HH24:MI:SS') || ' | ' ||
      SUBSTR(v_ViTriWKT,1,50) || '... | ' ||   
      v_VanToc || ' | ' ||
      v_HuongDiChuyen
    );
  END LOOP;
  CLOSE c_all;
END;
/
select * from CHU_TAU;

DECLARE
  c_owner SYS_REFCURSOR;
  v_MaTauCa       TAU_CA.MaTauCa%TYPE;
  v_ThoiGian      LOG_HAI_TRINH.ThoiGian%TYPE;
  v_ViTriWKT      CLOB;
  v_VanToc        LOG_HAI_TRINH.VanToc%TYPE;
  v_HuongDiChuyen LOG_HAI_TRINH.HuongDiChuyen%TYPE;
BEGIN
  -- Giả sử CT1 là MaChuTau
  get_newest_location_info_owner(
    p_cursor    => c_owner,
    p_MaChuTau  => 'USER2'
  );

  DBMS_OUTPUT.PUT_LINE('MaTauCa | ThoiGian            | ViTriWKT (gần đúng) | VanToc | HuongDiChuyen');
  DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------');
  LOOP
    FETCH c_owner INTO v_MaTauCa, v_ThoiGian, v_ViTriWKT, v_VanToc, v_HuongDiChuyen;
    EXIT WHEN c_owner%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(
      v_MaTauCa || ' | ' ||
      TO_CHAR(v_ThoiGian, 'YYYY-MM-DD HH24:MI:SS') || ' | ' ||
      SUBSTR(v_ViTriWKT,1,50) || '... | ' || 
      v_VanToc || ' | ' ||
      v_HuongDiChuyen
    );
  END LOOP;
  CLOSE c_owner;
END;
/

-- TEST Cap nhat trang thai roi cang 
-- TH1:tau chua dang ky chuyen danh bat
BEGIN
  update_working_status_depart(
    p_MaTauCa => 'TC1',
    p_CangDi  => 'Cảng Khởi Hành'  
  );
END;
/
select * from TAU_CA;
--TH2:tau da dang ky chuyen danh bat nhung chua duyet
BEGIN
  update_working_status_depart(
    p_MaTauCa => 'TC1',
    p_CangDi  => 'Cảng Khởi Hành'
  );
END;
/

UPDATE TAU_CA
SET TrangThaiHoatDong = 'DANG CHO|DA DK'
WHERE MaTauCa = 'TC1';


DECLARE
    v_cursor SYS_REFCURSOR;
    v_MaLogHaiTrinh LOG_HAI_TRINH.MaLogHaiTrinh%TYPE;
    v_ThoiGian      LOG_HAI_TRINH.ThoiGian%TYPE;
    v_ViTri         LOG_HAI_TRINH.ViTri%TYPE;
    v_VanToc        LOG_HAI_TRINH.VanToc%TYPE;
    v_HuongDiChuyen LOG_HAI_TRINH.HuongDiChuyen%TYPE;
    v_ViTri_WKT     VARCHAR2(4000);
BEGIN
    -- Gọi procedure
    get_log_list_CHUYEN_DANH_BAT(v_cursor, 'CDP2');

    LOOP
        FETCH v_cursor INTO v_MaLogHaiTrinh, v_ThoiGian, v_ViTri, v_VanToc, v_HuongDiChuyen;
        EXIT WHEN v_cursor%NOTFOUND;

        -- Chuyển geometry sang WKT để in
        v_ViTri_WKT := SDO_UTIL.TO_WKTGEOMETRY(v_ViTri);

        DBMS_OUTPUT.PUT_LINE('MaLog: ' || v_MaLogHaiTrinh ||
                             ', ThoiGian: ' || TO_CHAR(v_ThoiGian, 'YYYY-MM-DD HH24:MI:SS') ||
                             ', ViTri: ' || v_ViTri_WKT ||
                             ', VanToc: ' || v_VanToc ||
                             ', Huong: ' || v_HuongDiChuyen);
    END LOOP;

    CLOSE v_cursor;
END;

BEGIN
    insert_LOG_HAI_TRINH_for_CHUYEN_DANH_BAT(
        p_MaChuyenDanhBat   => 'CDP2',
        p_ThoiGian          => SYSDATE,
        p_ViTri             => 'POINT(106.7 10.8)',
        p_VanToc            => 5.5,
        p_HuongDiChuyen     => 'BẮC'
    );
    DBMS_OUTPUT.PUT_LINE('Insert log successful.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

SET DEFINE OFF;
SET SERVEROUTPUT ON;

DECLARE
    thong_tin_tau_cursor      SYS_REFCURSOR;
    thong_tin_danh_bat_cursor SYS_REFCURSOR;

    -- Biến cho cursor 1
    v_HoTen        CHU_TAU.HoTen%TYPE;
    v_MaTauCa      TAU_CA.MaTauCa%TYPE;
    v_SoDangKy     TAU_CA.SoDangKy%TYPE;
    v_LoaiTau      TAU_CA.LoaiTau%TYPE;
    v_ChieuDai     TAU_CA.ChieuDai%TYPE;
    v_CongSuat     TAU_CA.CongSuat%TYPE;
    v_TenNghe      NGHE.TenNghe%TYPE;
    v_MaChuyen     CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    v_NgayXuatBen  CHUYEN_DANH_BAT.NgayXuatBen%TYPE;
    v_NgayCapBen   CHUYEN_DANH_BAT.NgayCapBen%TYPE;
    v_CangDi       CHUYEN_DANH_BAT.CangDi%TYPE;
    v_CangVe       CHUYEN_DANH_BAT.CangVe%TYPE;

    -- Biến cho cursor 2
    v_MaMeCa           ME_CA.MaMeCa%TYPE;
    v_KhoiLuongMeCa    ME_CA.KhoiLuongMeCa%TYPE;
    v_ThoiGianThaLuoi  ME_CA.ThoiGianThaLuoi%TYPE;
    v_ThoiGianKeoLuoi  ME_CA.ThoiGianKeoLuoi%TYPE;
    v_ViTriWKT         VARCHAR2(4000);
    v_ChiTietMeCa      VARCHAR2(4000);

BEGIN
    GET_FISHING_DIARY(thong_tin_tau_cursor, thong_tin_danh_bat_cursor, 'CDP2');

    LOOP
        FETCH thong_tin_tau_cursor INTO 
            v_HoTen, v_MaTauCa, v_SoDangKy, v_LoaiTau, v_ChieuDai, v_CongSuat,
            v_TenNghe, v_MaChuyen, v_NgayXuatBen, v_NgayCapBen, v_CangDi, v_CangVe, v_TenNghe;
        EXIT WHEN thong_tin_tau_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('--- Tàu: ' || v_MaTauCa || ' - ' || v_SoDangKy || ' ---');
        DBMS_OUTPUT.PUT_LINE('Chủ tàu: ' || v_HoTen || ' | Công suất: ' || v_CongSuat || ' | Nghe: ' || v_TenNghe);
        DBMS_OUTPUT.PUT_LINE('Cảng đi: ' || v_CangDi || ' | về: ' || v_CangVe);
    END LOOP;
    CLOSE thong_tin_tau_cursor;

    LOOP
        FETCH thong_tin_danh_bat_cursor INTO 
            v_MaMeCa, v_KhoiLuongMeCa, v_ThoiGianThaLuoi, v_ThoiGianKeoLuoi, v_ViTriWKT, v_ChiTietMeCa;
        EXIT WHEN thong_tin_danh_bat_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('Mẻ: ' || v_MaMeCa || ' | KL: ' || v_KhoiLuongMeCa || ' | Chi tiết: ' || v_ChiTietMeCa);
    END LOOP;
    CLOSE thong_tin_danh_bat_cursor;
END;
/



BEGIN
    insert_LOG_DUONG_DI_BAO(
        p_MaBao     => 'BAO1',
        p_ThoiGian  => TO_TIMESTAMP('2025-06-08 15:00:00', 'YYYY-MM-DD HH24:MI:SS'),
        p_ViTriWKT  => 'POINT(110.5 13.7)',
        p_MucDo     => 1
    );

    DBMS_OUTPUT.PUT_LINE('Thêm log đường đi bão thành công!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Lỗi: ' || SQLERRM);
END;
/

select * from LOG_DUONG_DI_BAO;


DECLARE
    v_cursor SYS_REFCURSOR;
    v_NgayDuBao DATE;
    v_row THOI_TIET%ROWTYPE;
BEGIN
    
    v_NgayDuBao := null;

 
    get_weather_info(v_cursor, v_NgayDuBao);

    
    LOOP
        FETCH v_cursor INTO v_row;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaDuBao: ' || v_row.MaDuBao ||
                             ', ThoiGianDuBao: ' || v_row.ThoiGianDuBao ||
                             ', KhuVucAnhHuong: ' || v_row.KhuVucAnhHuong ||
                             ', ChiTietDuBao: ' || v_row.ChiTietDuBao);
    END LOOP;
    CLOSE v_cursor;
END;
/

select * from THOI_TIET;

-- Test procedure get_storm_list
DECLARE
    bao_cursor SYS_REFCURSOR;
    rec        BAO%ROWTYPE;
BEGIN
    get_storm_list(bao_cursor);

   
    LOOP
        FETCH bao_cursor INTO rec;
        EXIT WHEN bao_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaBao: ' || rec.MaBao || ', TenBao: ' || rec.TenBao);
    END LOOP;

    CLOSE bao_cursor;
END;
/

DECLARE
    bao_cursor SYS_REFCURSOR;
    v_MaLogDuongDi LOG_DUONG_DI_BAO.MaLogDuongDi%TYPE;
    v_ThoiGian    LOG_DUONG_DI_BAO.ThoiGian%TYPE;
    v_ViTriWKT    VARCHAR2(4000);
    v_MucDo       LOG_DUONG_DI_BAO.MucDo%TYPE;
BEGIN
    get_storm_info(bao_cursor, 'BAO1'); 

    
    LOOP
        FETCH bao_cursor INTO v_MaLogDuongDi, v_ThoiGian, v_ViTriWKT, v_MucDo;
        EXIT WHEN bao_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaLogDuongDi: ' || v_MaLogDuongDi || ', ThoiGian: ' || v_ThoiGian || ', ViTriWKT: ' || v_ViTriWKT || ', MucDo: ' || v_MucDo);
    END LOOP;

    CLOSE bao_cursor;
END;
/

DECLARE
    p_cursor SYS_REFCURSOR;
    v_MaTauCa TAU_CA.MaTauCa%TYPE;
    v_SoDangKy TAU_CA.SoDangKy%TYPE;
BEGIN
    get_ships_list(p_cursor);
    LOOP
        FETCH p_cursor INTO v_MaTauCa, v_SoDangKy;
        EXIT WHEN p_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaTauCa: ' || v_MaTauCa || ', SoDangKy: ' || v_SoDangKy);
    END LOOP;
    CLOSE p_cursor;
END;
/

select * from CHU_TAU;
DECLARE
    p_cursor SYS_REFCURSOR;
    v_MaTauCa TAU_CA.MaTauCa%TYPE;
    v_SoDangKy TAU_CA.SoDangKy%TYPE;
BEGIN
    get_owner_ships_list(p_cursor, 'USER2'); 
    LOOP
        FETCH p_cursor INTO v_MaTauCa, v_SoDangKy;
        EXIT WHEN p_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaTauCa: ' || v_MaTauCa || ', SoDangKy: ' || v_SoDangKy);
    END LOOP;
    CLOSE p_cursor;
END;
/

DECLARE
    chu_tau_cursor SYS_REFCURSOR;
    v_MaChuTau CHU_TAU.MaChuTau%TYPE;
    v_HoTen CHU_TAU.HoTen%TYPE;
    v_CCCD CHU_TAU.CCCD%TYPE;
    v_TrangThaiDuyet CHU_TAU.TrangThaiDuyet%TYPE;
BEGIN
    get_owners_pending_list(chu_tau_cursor);
    LOOP
        FETCH chu_tau_cursor INTO v_MaChuTau, v_HoTen, v_CCCD, v_TrangThaiDuyet;
        EXIT WHEN chu_tau_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaChuTau: ' || v_MaChuTau || ', HoTen: ' || v_HoTen || ', CCCD: ' || v_CCCD || ', TrangThaiDuyet: ' || v_TrangThaiDuyet);
    END LOOP;
    CLOSE chu_tau_cursor;
END;
/

DECLARE
    p_cursor SYS_REFCURSOR;
    v_MaTauCa TAU_CA.MaTauCa%TYPE;
    v_SoDangKy TAU_CA.SoDangKy%TYPE;
    v_TrangThaiDuyet TAU_CA.TrangThaiDuyet%TYPE;
BEGIN
    get_ships_pending_list(p_cursor);
    LOOP
        FETCH p_cursor INTO v_MaTauCa, v_SoDangKy, v_TrangThaiDuyet;
        EXIT WHEN p_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaTauCa: ' || v_MaTauCa || ', SoDangKy: ' || v_SoDangKy || ', TrangThaiDuyet: ' || v_TrangThaiDuyet);
    END LOOP;
    CLOSE p_cursor;
END;
/

DECLARE
    chu_tau_cursor SYS_REFCURSOR;
    
    v_MaChuTau CHU_TAU.MaChuTau%TYPE;
    v_HoTen CHU_TAU.HoTen%TYPE;
    v_SDT CHU_TAU.SDT%TYPE;
    v_DiaChi CHU_TAU.DiaChi%TYPE;
    v_CCCD CHU_TAU.CCCD%TYPE;
    v_TrangThaiDuyet CHU_TAU.TrangThaiDuyet%TYPE;
BEGIN
    get_owner_info(chu_tau_cursor, 'USER2'); 
    LOOP
        FETCH chu_tau_cursor INTO v_MaChuTau, v_HoTen, v_SDT, v_DiaChi, v_CCCD, v_TrangThaiDuyet;
        EXIT WHEN chu_tau_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'MaChuTau: ' || v_MaChuTau 
            || ', HoTen: ' || v_HoTen 
            || ', SDT: ' || v_SDT
            || ', DiaChi: ' || v_DiaChi
            || ', CCCD: ' || v_CCCD 
            || ', TrangThaiDuyet: ' || v_TrangThaiDuyet);
    END LOOP;
    CLOSE chu_tau_cursor;
END;
/

DECLARE
    tau_ca_cursor SYS_REFCURSOR;

    v_MaTauCa TAU_CA.MaTauCa%TYPE;
    v_SoDangKy TAU_CA.SoDangKy%TYPE;
    v_LoaiTau TAU_CA.LoaiTau%TYPE;
    v_ChieuDai TAU_CA.ChieuDai%TYPE;
    v_CongSuat TAU_CA.CongSuat%TYPE;
    v_NamDongTau TAU_CA.NamDongTau%TYPE;
    v_TrangThaiDuyet TAU_CA.TrangThaiDuyet%TYPE;
    v_TrangThaiHoatDong TAU_CA.TrangThaiHoatDong%TYPE;
    v_MaChuTau TAU_CA.MaChuTau%TYPE;
    v_MaNgheChinh TAU_CA.MaNgheChinh%TYPE;
BEGIN
    get_ship_info(tau_ca_cursor, 'TC1');
    LOOP
        FETCH tau_ca_cursor INTO 
            v_MaTauCa, v_SoDangKy, v_LoaiTau, v_ChieuDai, v_CongSuat, v_NamDongTau,
            v_TrangThaiDuyet, v_TrangThaiHoatDong, v_MaChuTau, v_MaNgheChinh;
        EXIT WHEN tau_ca_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'MaTauCa: ' || v_MaTauCa 
            || ', SoDangKy: ' || v_SoDangKy 
            || ', LoaiTau: ' || v_LoaiTau
            || ', ChieuDai: ' || v_ChieuDai 
            || ', CongSuat: ' || v_CongSuat
            || ', NamDongTau: ' || v_NamDongTau
            || ', TrangThaiDuyet: ' || v_TrangThaiDuyet
            || ', TrangThaiHoatDong: ' || v_TrangThaiHoatDong
            || ', MaChuTau: ' || v_MaChuTau
            || ', MaNgheChinh: ' || v_MaNgheChinh
        );
    END LOOP;
    CLOSE tau_ca_cursor;
END;
/

DECLARE
    tau_ca_cursor SYS_REFCURSOR;
    v_MaTauCa TAU_CA.MaTauCa%TYPE;
    v_SoDangKy TAU_CA.SoDangKy%TYPE;
    v_TrangThaiHoatDong TAU_CA.TrangThaiHoatDong%TYPE;
BEGIN
    get_owner_ships_list_and_working_status(tau_ca_cursor, 'USER2'); -- Thay 'CHUTAU001' bằng MaChuTau thực tế
    LOOP
        FETCH tau_ca_cursor INTO v_MaTauCa, v_SoDangKy, v_TrangThaiHoatDong;
        EXIT WHEN tau_ca_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaTauCa: ' || v_MaTauCa || ', SoDangKy: ' || v_SoDangKy || ', TrangThaiHoatDong: ' || v_TrangThaiHoatDong);
    END LOOP;
    CLOSE tau_ca_cursor;
END;
/

DECLARE
    cdb_cursor SYS_REFCURSOR;
    
    v_MaChuyenDanhBat CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    v_NgayXuatBen CHUYEN_DANH_BAT.NgayXuatBen%TYPE;
    v_NgayCapBen CHUYEN_DANH_BAT.NgayCapBen%TYPE;
    v_CangDi CHUYEN_DANH_BAT.CangDi%TYPE;
    v_CangVe CHUYEN_DANH_BAT.CangVe%TYPE;
    v_TongKhoiLuong CHUYEN_DANH_BAT.TongKhoiLuong%TYPE;
    v_TrangThaiDuyet CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE;
    v_TrangThaiHoatDong CHUYEN_DANH_BAT.TrangThaiHoatDong%TYPE;
    v_MaTauCa CHUYEN_DANH_BAT.MaTauCa%TYPE;
    v_MaNguTruong CHUYEN_DANH_BAT.MaNguTruong%TYPE;
BEGIN
    get_voyages_info(cdb_cursor, 'CDP2'); 
    LOOP
        FETCH cdb_cursor INTO 
            v_MaChuyenDanhBat, v_NgayXuatBen, v_NgayCapBen, v_CangDi, v_CangVe, 
            v_TongKhoiLuong, v_TrangThaiDuyet, v_TrangThaiHoatDong, v_MaTauCa, v_MaNguTruong;
        EXIT WHEN cdb_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'MaChuyenDanhBat: ' || v_MaChuyenDanhBat
            || ', NgayXuatBen: ' || TO_CHAR(v_NgayXuatBen, 'DD-MM-YYYY')
            || ', NgayCapBen: ' || TO_CHAR(v_NgayCapBen, 'DD-MM-YYYY')
            || ', CangDi: ' || v_CangDi
            || ', CangVe: ' || v_CangVe
            || ', TongKhoiLuong: ' || v_TongKhoiLuong
            || ', TrangThaiDuyet: ' || v_TrangThaiDuyet
            || ', TrangThaiHoatDong: ' || v_TrangThaiHoatDong
            || ', MaTauCa: ' || v_MaTauCa
            || ', MaNguTruong: ' || v_MaNguTruong
        );
    END LOOP;
    CLOSE cdb_cursor;
END;
/

DECLARE
    cdb_cursor SYS_REFCURSOR;
    v_MaTauCa CHUYEN_DANH_BAT.MaTauCa%TYPE;
    v_MaChuyenDanhBat CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    v_TrangThaiDuyet CHUYEN_DANH_BAT.TrangThaiDuyet%TYPE;
BEGIN
    get_voyages_pending_list(cdb_cursor);
    LOOP
        FETCH cdb_cursor INTO v_MaTauCa, v_MaChuyenDanhBat, v_TrangThaiDuyet;
        EXIT WHEN cdb_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'MaTauCa: ' || v_MaTauCa 
            || ', MaChuyenDanhBat: ' || v_MaChuyenDanhBat
            || ', TrangThaiDuyet: ' || v_TrangThaiDuyet
        );
    END LOOP;
    CLOSE cdb_cursor;
END;
/

DECLARE
    cdb_cursor SYS_REFCURSOR;
    v_MaChuyenDanhBat CHUYEN_DANH_BAT.MaChuyenDanhBat%TYPE;
    v_TrangThaiHoatDong CHUYEN_DANH_BAT.TrangThaiHoatDong%TYPE;
BEGIN
    get_ship_voyages_list(cdb_cursor, 'TC1'); 
    LOOP
        FETCH cdb_cursor INTO v_MaChuyenDanhBat, v_TrangThaiHoatDong;
        EXIT WHEN cdb_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'MaChuyenDanhBat: ' || v_MaChuyenDanhBat
            || ', TrangThaiHoatDong: ' || v_TrangThaiHoatDong
        );
    END LOOP;
    CLOSE cdb_cursor;
END;
/

DECLARE
    p_cursor SYS_REFCURSOR;
    -- Biến tương ứng cột TAU_CA
    v_MaTauCa TAU_CA.MaTauCa%TYPE;
    v_SoDangKy TAU_CA.SoDangKy%TYPE;
    v_LoaiTau TAU_CA.LoaiTau%TYPE;
    v_ChieuDai TAU_CA.ChieuDai%TYPE;
    v_CongSuat TAU_CA.CongSuat%TYPE;
    v_NamDongTau TAU_CA.NamDongTau%TYPE;
    v_TrangThaiDuyet TAU_CA.TrangThaiDuyet%TYPE;
    v_TrangThaiHoatDong TAU_CA.TrangThaiHoatDong%TYPE;
    v_MaChuTau TAU_CA.MaChuTau%TYPE;
    v_MaNgheChinh TAU_CA.MaNgheChinh%TYPE;
BEGIN
    get_working_ships_list(p_cursor);
    LOOP
        FETCH p_cursor INTO
            v_MaTauCa, v_SoDangKy, v_LoaiTau, v_ChieuDai, v_CongSuat, v_NamDongTau,
            v_TrangThaiDuyet, v_TrangThaiHoatDong, v_MaChuTau, v_MaNgheChinh;
        EXIT WHEN p_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'MaTauCa: ' || v_MaTauCa 
            || ', SoDangKy: ' || v_SoDangKy 
            || ', LoaiTau: ' || v_LoaiTau
            || ', ChieuDai: ' || v_ChieuDai 
            || ', CongSuat: ' || v_CongSuat
            || ', NamDongTau: ' || v_NamDongTau
            || ', TrangThaiDuyet: ' || v_TrangThaiDuyet
            || ', TrangThaiHoatDong: ' || v_TrangThaiHoatDong
            || ', MaChuTau: ' || v_MaChuTau
            || ', MaNgheChinh: ' || v_MaNgheChinh
        );
    END LOOP;
    CLOSE p_cursor;
END;
/

DECLARE
    ngu_truong_cursor SYS_REFCURSOR;
    v_MaNguTruong NGU_TRUONG.MaNguTruong%TYPE;
    v_TenNguTruong NGU_TRUONG.TenNguTruong%TYPE;
BEGIN
    get_fishery_list(ngu_truong_cursor);
    LOOP
        FETCH ngu_truong_cursor INTO v_MaNguTruong, v_TenNguTruong;
        EXIT WHEN ngu_truong_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('MaNguTruong: ' || v_MaNguTruong || ', TenNguTruong: ' || v_TenNguTruong);
    END LOOP;
    CLOSE ngu_truong_cursor;
END;
/
