import { IsString, IsNotEmpty, IsNumber, IsEthereumAddress } from "class-validator";

export class CreateIdentityDto {
  @IsEthereumAddress()
  @IsNotEmpty()
  subjectAddress!: string;

  @IsString()
  @IsNotEmpty()
  documentContent!: string;

  @IsString()
  @IsNotEmpty()
  schemaName!: string;

  @IsNumber()
  expiresAt!: number;
}
